# ============================================================
# PREPARAR DADOS DA CAPACITAÇÃO
# Métricas da Paisagem Aplicadas à Fragilidade Configuracional
# ============================================================

library(sf)
library(dplyr)
library(stringr)

# ------------------------------------------------------------
# 1) Pastas
# ------------------------------------------------------------

dir_base <- "C:/Users/ENCOM/Documents/data_aula"
dir_dados <- file.path(dir_base, "dados")
dir_saida <- file.path(dir_base, "dados_capacitacao")

dir.create(dir_saida, showWarnings = FALSE)
dir.create(file.path(dir_saida, "florestas_por_municipio"), showWarnings = FALSE)


# ------------------------------------------------------------
# 3) Conferir se os arquivos existem
# ------------------------------------------------------------

if (!file.exists(arquivo_floresta)) {
  stop("Arquivo de floresta não encontrado: ", arquivo_floresta)
}

if (!file.exists(arquivo_municipios)) {
  stop("Arquivo de municípios não encontrado. Copie o shapefile de municípios para a pasta dados e renomeie para MUNICIPIOS.shp")
}

# ------------------------------------------------------------
# 4) Ler dados
# ------------------------------------------------------------

floresta <- st_read(arquivo_floresta)
municipios <- st_read(arquivo_municipios)

# ------------------------------------------------------------
# 5) Verificar colunas
# ------------------------------------------------------------

cat("\nColunas do shapefile de municípios:\n")
print(names(municipios))

# Ajuste se o nome da coluna for diferente
coluna_municipio <- "NM_MUN"

if (!coluna_municipio %in% names(municipios)) {
  stop("A coluna NM_MUN não foi encontrada. Veja os nomes acima e altere 'coluna_municipio'.")
}

# ------------------------------------------------------------
# 6) Padronizar projeção
# ------------------------------------------------------------

municipios <- st_transform(municipios, st_crs(floresta))

# ------------------------------------------------------------
# 7) Corrigir geometrias
# ------------------------------------------------------------

floresta <- st_make_valid(floresta)
municipios <- st_make_valid(municipios)

# ------------------------------------------------------------
# 8) Identificar municípios com floresta
# ------------------------------------------------------------

intersecta <- st_intersects(municipios, floresta, sparse = FALSE)

municipios_com_floresta <- municipios[rowSums(intersecta) > 0, ]

cat("\nMunicípios com floresta encontrados:", nrow(municipios_com_floresta), "\n")

# ------------------------------------------------------------
# 9) Recortar floresta por município
# ------------------------------------------------------------

floresta_municipios <- st_intersection(floresta, municipios_com_floresta)

floresta_municipios <- floresta_municipios %>%
  mutate(
    area_ha = as.numeric(st_area(.)) / 10000
  )

# ------------------------------------------------------------
# 10) Criar resumo por município
# ------------------------------------------------------------

resumo_municipios <- floresta_municipios %>%
  st_drop_geometry() %>%
  group_by(.data[[coluna_municipio]]) %>%
  summarise(
    n_fragmentos = n(),
    area_total_ha = sum(area_ha, na.rm = TRUE),
    area_media_ha = mean(area_ha, na.rm = TRUE),
    area_min_ha = min(area_ha, na.rm = TRUE),
    area_max_ha = max(area_ha, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(desc(area_total_ha))

print(resumo_municipios)

# ------------------------------------------------------------
# 11) Salvar resumo geral
# ------------------------------------------------------------

write.csv(
  resumo_municipios,
  file.path(dir_saida, "resumo_municipios_com_floresta.csv"),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

st_write(
  municipios_com_floresta,
  file.path(dir_saida, "municipios_com_floresta.shp"),
  delete_layer = TRUE
)

# ------------------------------------------------------------
# 12) Gerar um shapefile de floresta por município
# ------------------------------------------------------------

for (i in 1:nrow(municipios_com_floresta)) {
  
  muni_i <- municipios_com_floresta[i, ]
  nome_muni <- muni_i[[coluna_municipio]][1]
  
  nome_limpo <- nome_muni %>%
    str_replace_all("[ÁÀÂÃÄáàâãä]", "A") %>%
    str_replace_all("[ÉÈÊËéèêë]", "E") %>%
    str_replace_all("[ÍÌÎÏíìîï]", "I") %>%
    str_replace_all("[ÓÒÔÕÖóòôõö]", "O") %>%
    str_replace_all("[ÚÙÛÜúùûü]", "U") %>%
    str_replace_all("[Çç]", "C") %>%
    str_replace_all("[^A-Za-z0-9]", "_")
  
  cat("\nGerando shapefile:", nome_muni)
  
  floresta_i <- st_intersection(floresta, muni_i)
  
  if (nrow(floresta_i) > 0) {
    
    floresta_i <- floresta_i %>%
      mutate(
        municipio = nome_muni,
        fid = row_number()
      )
    
    st_write(
      floresta_i,
      file.path(
        dir_saida,
        "florestas_por_municipio",
        paste0(nome_limpo, "_floresta.shp")
      ),
      delete_layer = TRUE,
      quiet = TRUE
    )
  }
}

# ------------------------------------------------------------
# 13) Criar tabela para distribuir entre alunos
# ------------------------------------------------------------

distribuicao_alunos <- resumo_municipios %>%
  mutate(
    aluno = paste0("Aluno_", row_number())
  ) %>%
  select(
    aluno,
    municipio = .data[[coluna_municipio]],
    n_fragmentos,
    area_total_ha,
    area_media_ha
  )

write.csv(
  distribuicao_alunos,
  file.path(dir_saida, "distribuicao_municipios_alunos.csv"),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

# ------------------------------------------------------------
# 14) Mensagem final
# ------------------------------------------------------------

cat("\n\nPROCESSAMENTO CONCLUÍDO!\n")
cat("Arquivos gerados em:\n")
cat(dir_saida, "\n\n")
cat("Principais saídas:\n")
cat("- resumo_municipios_com_floresta.csv\n")
cat("- municipios_com_floresta.shp\n")
cat("- florestas_por_municipio/\n")
cat("- distribuicao_municipios_alunos.csv\n")

