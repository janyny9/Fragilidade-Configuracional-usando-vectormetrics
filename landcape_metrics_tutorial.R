# ============================================================
# CÁLCULO DE MÉTRICAS E CLASSIFICAÇÃO DA FRAGILIDADE
# ============================================================

# ------------------------------------------------------------
# 1) Pacotes
# ------------------------------------------------------------

# install.packages("remotes")
# remotes::install_github("r-spatialecology/vectormetrics")

library(vectormetrics)
library(sf)
library(dplyr)
library(tidyr)
library(ggplot2)

# ------------------------------------------------------------
# 2) Ler shapefile
# ------------------------------------------------------------

vetor <- st_read("FLORESTA_2023.shp")

# Garantir que o fid seja caractere
vetor <- vetor %>%
  mutate(fid = as.character(fid))

# ------------------------------------------------------------
# 3) Calcular métricas
# ------------------------------------------------------------

area <- vm_p_area(
  landscape = vetor,
  class_col = "gridcode",
  patch_col = "fid"
) %>%
  rename(area = value)

forma <- vm_p_shape(
  landscape = vetor,
  class_col = "gridcode",
  patch_col = "fid"
) %>%
  rename(forma = value)

core_area <- vm_p_core(
  landscape = vetor,
  class_col = "gridcode",
  patch_col = "fid",
  edge_depth = 50
) %>%
  rename(area_nucleo = value)

cai <- vm_p_cai(
  landscape = vetor,
  class_col = "gridcode",
  patch_col = "fid",
  edge_depth = 50
) %>%
  rename(perc_area_nucleo = value)

nndist <- vm_p_enn(
  landscape = vetor,
  class_col = "gridcode",
  patch_col = "fid"
) %>%
  rename(nndist = value)

# ------------------------------------------------------------
# 4) Juntar métricas
# ------------------------------------------------------------

dados_combinados <- area %>%
  select(id, class, area) %>%
  left_join(forma %>% select(id, forma), by = "id") %>%
  left_join(core_area %>% select(id, area_nucleo), by = "id") %>%
  left_join(cai %>% select(id, perc_area_nucleo), by = "id") %>%
  left_join(nndist %>% select(id, nndist), by = "id")

# ------------------------------------------------------------
# 5) Classificar fragilidade
# ------------------------------------------------------------

fragilidade <- dados_combinados %>%
  mutate(
    nivel_fragilidade = case_when(
      
      is.na(area) | is.na(forma) | is.na(perc_area_nucleo) ~ "NC",
      area == 0 | forma == 0 ~ "NC",
      
      # Alta fragilidade
      area <= 1 & perc_area_nucleo == 0 & forma >= 1.5 ~ "AL-I",
      area > 1 & area <= 2 & perc_area_nucleo == 0 & forma >= 1.5 ~ "AL-II",
      area > 2 & area <= 3 & perc_area_nucleo == 0 & forma >= 1.5 ~ "AL-III",
      area > 3 & area <= 5 & perc_area_nucleo == 0 & forma >= 1.5 ~ "AL-IV",
      area <= 5 & perc_area_nucleo > 0 & forma > 1.5 ~ "AL-V",
      area <= 5 & perc_area_nucleo > 0 & forma <= 1.5 ~ "AL-VI",
      
      # Fragilidade intermediária
      area > 5 & area <= 15 & perc_area_nucleo >= 0 & forma >= 1.5 ~ "IN-I",
      area > 15 & area <= 50 & perc_area_nucleo >= 0 & forma >= 1.5 ~ "IN-II",
      area > 5 & area <= 50 & perc_area_nucleo >= 0 & forma < 1.5 ~ "IN-III",
      
      # Baixa fragilidade
      area >= 50 & perc_area_nucleo < 25 & forma > 1.5 ~ "BA-I",
      area >= 50 & perc_area_nucleo < 25 & forma <= 1.5 ~ "BA-II",
      area > 50 & perc_area_nucleo >= 25 & forma >= 1.5 ~ "BA-III",
      area > 50 & perc_area_nucleo >= 25 & forma < 1.5 ~ "BA-IV",
      
      TRUE ~ "NC"
    )
  )

# ------------------------------------------------------------
# 6) Diagnóstico dos fragmentos NC
# ------------------------------------------------------------

dados_nc <- fragilidade %>%
  filter(nivel_fragilidade == "NC")

print(dados_nc)

# Quantidade de NC
cat("\nNúmero de fragmentos NC:", nrow(dados_nc), "\n")

# Resumo dos NC
resumo_nc <- dados_nc %>%
  summarise(
    n = n(),
    area_min = min(area, na.rm = TRUE),
    area_media = mean(area, na.rm = TRUE),
    area_mediana = median(area, na.rm = TRUE),
    area_max = max(area, na.rm = TRUE),
    forma_min = min(forma, na.rm = TRUE),
    forma_media = mean(forma, na.rm = TRUE),
    forma_mediana = median(forma, na.rm = TRUE),
    forma_max = max(forma, na.rm = TRUE),
    cai_min = min(perc_area_nucleo, na.rm = TRUE),
    cai_media = mean(perc_area_nucleo, na.rm = TRUE),
    cai_mediana = median(perc_area_nucleo, na.rm = TRUE),
    cai_max = max(perc_area_nucleo, na.rm = TRUE)
  )

print(resumo_nc)

# Ver quais combinações estão virando NC
perfil_nc <- dados_nc %>%
  mutate(
    classe_area = case_when(
      area <= 1 ~ "<= 1 ha",
      area > 1 & area <= 2 ~ "1-2 ha",
      area > 2 & area <= 3 ~ "2-3 ha",
      area > 3 & area <= 5 ~ "3-5 ha",
      area > 5 & area <= 15 ~ "5-15 ha",
      area > 15 & area <= 50 ~ "15-50 ha",
      area > 50 ~ "> 50 ha",
      TRUE ~ "sem área"
    ),
    classe_cai = case_when(
      is.na(perc_area_nucleo) ~ "CAI NA",
      perc_area_nucleo == 0 ~ "CAI = 0",
      perc_area_nucleo > 0 & perc_area_nucleo < 25 ~ "CAI 0-25",
      perc_area_nucleo >= 25 ~ "CAI >= 25",
      TRUE ~ "outro CAI"
    ),
    classe_forma = case_when(
      is.na(forma) ~ "forma NA",
      forma < 1.5 ~ "forma < 1.5",
      forma >= 1.5 ~ "forma >= 1.5",
      TRUE ~ "outra forma"
    )
  ) %>%
  count(classe_area, classe_cai, classe_forma, sort = TRUE)

print(perfil_nc)

# Salvar tabela dos NC para avaliar manualmente
write.csv(
  dados_nc,
  "diagnostico_fragmentos_NC_2023.csv",
  row.names = FALSE
)

write.csv(
  perfil_nc,
  "perfil_resumido_NC_2023.csv",
  row.names = FALSE
)

# ------------------------------------------------------------
# 7) Gráficos rápidos dos NC
# ------------------------------------------------------------

ggplot(dados_nc, aes(x = area)) +
  geom_histogram(bins = 30) +
  labs(
    title = "Distribuição da área dos fragmentos NC",
    x = "Área",
    y = "Número de fragmentos"
  )

ggplot(dados_nc, aes(x = forma)) +
  geom_histogram(bins = 30) +
  labs(
    title = "Distribuição do índice de forma dos fragmentos NC",
    x = "Índice de forma",
    y = "Número de fragmentos"
  )

ggplot(dados_nc, aes(x = perc_area_nucleo)) +
  geom_histogram(bins = 30) +
  labs(
    title = "Distribuição do CAI dos fragmentos NC",
    x = "% de área núcleo",
    y = "Número de fragmentos"
  )

# ------------------------------------------------------------
# 8) Juntar classificação ao shapefile original
# ------------------------------------------------------------

vetor_fragilidade <- vetor %>%
  left_join(
    fragilidade,
    by = c("fid" = "id")
  )

# Garantir objeto sf
vetor_fragilidade <- st_as_sf(vetor_fragilidade)

# ------------------------------------------------------------
# 9) Exportar shapefile final
# ------------------------------------------------------------

st_write(
  vetor_fragilidade,
  "fragilidade_paisagem.shp",
  delete_layer = TRUE
)