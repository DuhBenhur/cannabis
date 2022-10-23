# cannabis
Repositório criado para publicação do trabalho final do curso de web scraping da Curso-R e também para futuras análises de dados canabicos


---
title: "Curso-R - Trabalho Final"
subtitle: "Raspagem de dados e clusterização de canabinóides"
author: "Eduardo Ben-Hur De Queiroz Gomes"
date: \today
output: html_document
---

```{r setup, include=FALSE}
knitr::opts_chunk$set(echo = TRUE)
```

# Introdução

Neste projeto vou apresentar o trabalho final do curso de "Web scraping" da [Curso-R](www.curso-r.com). A ideia aqui é ter um primeiro contato com rapagem de dados de sites e também, ter uma entrega paralela como trabalho de conclusão do **VIII Curso de Cannabis Medicinal** da [Unifesp](https://sp.unifesp.br/epm/eventos-epm/viii-curso-de-cannabis-medicinal).
<br/>
<br/>

## Principais etapas

Veremos os seguintes pontos nesse documento:

* Descrição da página web acessada
* Como a requisição foi imitada?
* Como foi realizada a iteração?
* Como é o arquivo parseado?
* Documentação final
<br/>
<br/>

### Descrição da página web acessada

Alguns países possuem sites de vendas de sementes para cultivadores que desejam plantar 
maconha em suas próprias casas.

Um desses sites é a plataforma [Seed Bank](https://www.seedbank.com/) que foi projetada
para disponibilizar sementes premium para cultivadores com uma excelente variedade e excelentes
preços.
<br/>
<br/>
<br/>

![](img/home.png)
<br/>
<br/>

Já dentro do site, o interesse está nas sementes feminizadas que são sementes de cannabis que possuem genética para produzir apenas ervas femeas.
<br/>
<br/>
<br/>
![](img/feminized.png)
<br/>
<br/>

Os canabinoides são compostos naturais da planta. Os canabinoides mais famosos e conhecidos, são o delta-9-tetraidrocanabinol (THC) e o canabidiol (CBD). O THC é o componente psicoativo da Cannabis e o principal responsável  pelos efeitos físicos e psíquicos, a famosa brisa. Já o CBD tem o seu efeito principalmente ao interagir com receptores específicos nas células do cérebro e do corpo e é muito utilizado de forma medicinal por conta dos seus efeitos anticonvulsionantes, anti-inflamatórios e antitumorais. 

Para saber um pouco mais sobre o assunto, recomendo uma breve visita a página da wikipedia sobre [Canabidiol](https://pt.wikipedia.org/wiki/Canabidiol).

Voltando a página de interesse, foram coletadas as informações sobre os principais canabinóides de cada variedade de semente.
<br/>
<br/>
<br/>

![](img/cannabinoid.png)
<br/>
<br/>

Foram raspados os dados dos "Cannabinoid Totals" de cada uma das sementes feminizadas presentes no site.

Com essa pequena introdução e descrição da página, vamos começar a coleta de dados e análise de cluster das sementes.

Em primeiro lugar, foram carregados os pacotes que serão ferramentas para realização da raspagem de dados e também da clusterização.

  
```{r Carregar pacotes, echo=TRUE, message=FALSE, warning=FALSE}
pacotes <- c(
  "tidyverse",
  "cluster",
  "dendextend",
  "factoextra",
  "fpc",
  "gridExtra",
  "magrittr",
  "knitr",
  "kableExtra",
  "purrr",
  "xml2",
  "progressr",
  "purrr"
)
if (sum(as.numeric(!pacotes %in% installed.packages())) != 0) {
  instalador <- pacotes[!pacotes %in% installed.packages()]
  for (i in 1:length(instalador)) {
    install.packages(instalador, dependencies = T)
    break()
  }
  sapply(pacotes, require, character = T)
} else{
  sapply(pacotes, require, character = T)
}
```
<br/>
<br/>

### Como a requisição foi imitada?

O primeiro passo, foi localizar a URL principal que contém todas as sementes daquela página específica e realizar uma requisição para obter os links daquela página.

O que eu chamo de URL mãe, é essa url principal que foi a primeira a ser acessada.
<br/>
<br/>
<br/>


![](img/urlmae.png)

<br/>
<br/>

A requisição da url mãe foi realizada e o arquivo html foi salvo localmente através do código abaixo.

```{r}
u_links <- "https://www.seedbank.com/collections/feminized-seeds/"
r_links <-
  httr::GET(u_links,
            httr::write_disk("output/strains/feminized.html", overwrite = TRUE))
r_links
```
Depois de realizar essa requisição GET no site, obtivemos o status 200 e um arquivo de quase 200kB.
Com a página em mãos, foi necessário imitar a requisição que acessa o link de uma semente e para isso, os elementos da página foram inspecionados.
<br/>
<br/>
<br/>

![](img/inspecao.png)
<br/>
<br/>

Atráves da inspeção, foi possível localizar um elemento html que poderia ser acessado para retornar o link de todas sementes daquela página específica. Para acessar, utilizou-se o código abaixo utilizando o xpath do elemento e em seguida extraindo as urls (**href**) que obedecem ao filtro realizado com xpath.

```{r}
links <- r_links |>
  xml2::read_html() |>
  xml2::xml_find_all("//div[@class = 'add-to-cart-button']/a")
urls <- xml2::xml_attr(links, "href")
urls
```

Além das urls, também foi interessante obter o nome de cada uma das sementes, para construção do futuro dataset.
para obtenção dos nomes, o código abaixo foi executado, obtendo o nome da própria url da semente.

```{r}
txt <-
  xml2::url_relative(urls, "https://www.seedbank.com/products/") |>
  #remover traços e barras com regex
  stringr::str_replace_all("[[-/]]", " ") |>
  trimws()#remover espaço no final
txt
```

Com o link e nome das variedades de sementes em mãos, já temos duas colunas do nosso dataset. Agora vamos para o mais importante, a coleta dos nomes dos canabinoides e também dos valores percentuais de cada um deles.

Para isso, novamente foi necessário realizar uma inspeção de elementos na página, para obter os nomes de cada canabinoide da variedade.

<br/>
<br/>
<br/>

![](img/nomes_cannabinoids.png)

<br/>
<br/>

Com a informação do elemento html, os seguintes códigos foram executados para obtenção dos nomes dos canabinoidese também dos valores de cada um deles.

```{r}
html <- urls |>
    purrr::map(read_html)
  nome <- html |>
    purrr::map(xml_find_all, "//*[@class='pie_progress__label']") |>
    purrr::map(xml_text) |>
  #substitui retornos character(0) por THC. Foi necessario pois existem duas sementes que possuem uma estrutura diferente de apresentação dos valores dos canabinoides.
    lapply(\(x) if (identical(x, character(0)))
      "THC"
      else
        x)
nome
```

E para os valores.

```{r}
  
  valor <- html |>
    purrr::map(xml2::xml_find_all, "//*[@class='pie_progress']") |>
    purrr::map(xml2::xml_attr, "data-goal") |>
    purrr::map(as.numeric) |>
    lapply(\(x) if (identical(x, numeric(0)))
      0
      else
        x)
valor
```

E por fim, uma função para organizar os nomes dos canabinóides com os seus respectivos valores.

```{r}
dados_valores <-
    purrr::map2(nome, valor, \(x, y) tibble::tibble(name = x, value = y)) |>
    purrr::map_dfr(tidyr::pivot_wider) |>
    # substitui NAs por zero
    dplyr::mutate(dplyr::across(.fns = tidyr::replace_na, replace = 0))
dados_valores
```

A última etapa do processo, foi a etapa de união das colunas de valores com as colunas de nomes e links.

```{r}
  saida <- tibble::tibble(semente = txt, link = urls) |>
    dplyr::bind_cols(dados_valores) |>
    dplyr::mutate(link = stringr::str_squish(link))
saida
```

### Como foi realizada a iteração?

Para realizar a iteração, foi necessário entender primeiro, quantas páginas seriam acessadas e também quantos links seriam obtidos em cada página.

Esses valores podem ser encontrados na parte superior da página mãe.

![](img/n_pags_results.png)

Para coletar essa informação, foi necessário inspecionar o elemento e obter o xpath.

![](img/n_pags_inspect.png)
Em seguida, o seguinte código foi executado para obter o número de páginas e a quantidade total de itens.

```{r}
n_resultados <- r_links |>
  httr::content() |>
  xml2::xml_find_first("//p[@class = 'woocommerce-result-count hide-for-medium']") |>
  xml2::xml_text() |>
  stringr::str_squish() |>
  stringr::str_extract("[0-9][0-9][0-9]") |>
  as.numeric()
n_pags <- n_resultados %/% 12 + 1
n_resultados
n_pags
```
Com isso para iterar, foi criado um vetor para coletar todas as páginas.

```{r}
vetor_paginas <- 1:n_pags
```

E todas os trechos de código necessários para raspar os dados e coletar as informações, foram encapsulados em uma função.

```{r}
baixar_pagina <- function(pag, prog = NULL) {
  Sys.sleep(1)
  
  if (!is.null(prog))
    prog()
  u_pag <-
    glue::glue("https://www.seedbank.com/collections/feminized-seeds/page/{pag}/")
  httr::GET(u_pag, httr::write_disk(
    glue::glue("output/strains/pagina_{pag}.html"),
    overwrite = TRUE
  ))
  
  links <- u_pag |>
    xml2::read_html() |>
    xml2::xml_find_all("//div[@class = 'add-to-cart-button']/a")
  
  urls <- xml2::xml_attr(links, "href")
  
  html <- urls |>
    map(read_html)
  
  nome <- html |>
    map(xml_find_all, "//*[@class='pie_progress__label']") |>
    map(xml_text) |>
    lapply(\(x) if (identical(x, character(0)))
      "THC"
      else
        x)
  
  
  valor <- html |>
    map(xml2::xml_find_all, "//*[@class='pie_progress']") |>
    map(xml2::xml_attr, "data-goal") |>
    map(as.numeric) |>
    lapply(\(x) if (identical(x, numeric(0)))
      0
      else
        x)
  
  dados_valores <-
    map2(nome, valor, \(x, y) tibble::tibble(name = x, value = y)) |>
    map_dfr(tidyr::pivot_wider) |>
    # substitui NAs por zero
    dplyr::mutate(dplyr::across(.fns = tidyr::replace_na, replace = 0))
  
  txt <-
    xml2::url_relative(urls, "https://www.seedbank.com/products/") |>
    stringr::str_replace_all("[[/-]]", " ") |>
    trimws()
  
  saida <- tibble::tibble(semente = txt, link = urls) |>
    dplyr::bind_cols(dados_valores) |>
    dplyr::mutate(link = stringr::str_squish(link))
  
  return(saida)
}
```

Por último, essa função recebeu o vetor já criado e iterou por todas as páginas de interesse.

```{r}
progressr::with_progress({
  p <- progressr::progressor(n_pags)
  tab <- purrr::map_dfr(vetor_paginas, baixar_pagina, prog = p)
  Sys.sleep(1)
})
```



### Como é o arquivo parseado?

Os primeiros 50 resultados do arquivo parseado, pode ser visto na tabela abaixo. 
Essa tabela é o dataset final da raspagem de dados e insumo inicial para elaboração da analise de clusters.


```{r echo=FALSE, message=FALSE, warning=FALSE, paged.print=FALSE}
print(tab,n = 50)
```
