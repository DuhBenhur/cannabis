
# passo 0 - pacotes -------------------------------------------------------

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
  "progressr"
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



# passo 1 - busca ---------------------------------------------------------


u_links <- "https://www.seedbank.com/collections/feminized-seeds/"

r_links <-
  httr::GET(u_links,
            httr::write_disk("output/strains/feminized.html", overwrite = TRUE))

links <- r_links |>
  xml2::read_html() |>
  xml2::xml_find_all("//div[@class = 'add-to-cart-button']/a")

urls <- xml2::xml_attr(links, "href")

txt <-
  xml2::url_relative(urls, "https://www.seedbank.com/products/") |>
  stringr::str_replace_all("[[-/]]", " ") |>
  trimws()

# passo 2 - quantidade de paginas -----------------------------------------

n_resultados <- r_links |>
  httr::content() |>
  xml2::xml_find_first("//p[@class = 'woocommerce-result-count hide-for-medium']") |>
  xml2::xml_text() |>
  stringr::str_squish() |>
  stringr::str_extract("[0-9][0-9][0-9]") |>
  as.numeric()

n_pags <- n_resultados %/% 12 + 1

# passo 3 - pegar uma pagina ----------------------------------------------

pag <- 1

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

# passo 4 - pegar várias páginas ------------------------------------------

vetor_paginas <- 1:n_pags
progressr::with_progress({
  p <- progressr::progressor(n_pags)
  tab <- purrr::map_dfr(vetor_paginas, baixar_pagina, prog = p)
  Sys.sleep(1)
})

View(tab)

readr::write_csv2(tab, "output/strains/seedbank.csv")



# passo 5 - Análise de Clusters -------------------------------------------
base <- as.data.frame(tab)
base_filtrada <- dplyr::filter(base,
                               semente != "alaskan thunder fuck seeds" &
                                 semente != "sweet island skunk seeds")



feminized_seeds <- dplyr::select(base_filtrada, everything(), -link)

glimpse(feminized_seeds)

rownames(feminized_seeds) <- feminized_seeds[, 1]
feminized_seeds <- feminized_seeds[,-1]

feminized_seeds.padronizado <- scale(feminized_seeds)


#Percentil


percentil_var <- function(x) {
  percentil <- quantile(
    x,
    probs = c(0.25, 0.50, 0.75),
    type = 5,
    na.rm = T
  )
  return(percentil)
}

percentil_var(feminized_seeds$THC)
percentil_var(feminized_seeds$CBD)

#Cluster não hierarquico


feminized_seeds.k2 <-
  kmeans(feminized_seeds.padronizado, centers = 2)

#Visualizar os clusters

fviz_cluster(feminized_seeds.k2, data = feminized_seeds.padronizado, main = "Cluster k2")



#Criando Clusters

feminized_seeds.k3 <-
  kmeans(feminized_seeds.padronizado, centers = 3)
feminized_seeds.k4 <-
  kmeans(feminized_seeds.padronizado, centers = 4)
feminized_seeds.k5 <-
  kmeans(feminized_seeds.padronizado, centers = 5)
feminized_seeds.k6 <-
  kmeans(feminized_seeds.padronizado, centers = 6)

tipo_geom <- "points"
#Criar graficos
G2 <-
  fviz_cluster(feminized_seeds.k2, geom = tipo_geom, data = feminized_seeds.padronizado) + ggtitle("k = 2")
G3 <-
  fviz_cluster(feminized_seeds.k3, geom = tipo_geom, data = feminized_seeds.padronizado) + ggtitle("k = 3")
G4 <-
  fviz_cluster(feminized_seeds.k4, geom = tipo_geom, data = feminized_seeds.padronizado) + ggtitle("k = 4")
G5 <-
  fviz_cluster(feminized_seeds.k5, geom = tipo_geom, data = feminized_seeds.padronizado) + ggtitle("k = 5")
G6 <-
  fviz_cluster(feminized_seeds.k6, geom = tipo_geom, data = feminized_seeds.padronizado) + ggtitle("k = 6")


#Imprimir graficos na mesma tela
grid.arrange(G2, G3, G4, G5, G6, nrow = 2)

#VERIFICANDO ELBOW
fviz_nbclust(feminized_seeds.padronizado, kmeans, method = "wss") +
  geom_vline(xintercept = 5, linetype = 6)


#Average silhouette for kmeans


fviz_nbclust(feminized_seeds.padronizado, kmeans, method = "silhouette")


fit <- data.frame(feminized_seeds.k5$cluster)

feminized_seeds_fit <- cbind(base_filtrada, fit)


resumo_medio <- feminized_seeds_fit |>
  group_by(feminized_seeds.k5.cluster) |>
  summarise(
    n = n(),
    THC = mean(THC),
    CBD = mean(CBD),
    CBG = mean(CBG),
    CBN = mean(CBN)
  ) |>
  ungroup() |> droplevels(.)



gap_stat <-
  clusGap(
    feminized_seeds.padronizado,
    FUN = kmeans,
    nstart = 25,
    K.max = 10,
    B = 300
  )
print(gap_stat, method = "firstmax")
fviz_gap_stat(gap_stat)
