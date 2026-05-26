# ============================================================
# MÉTRICAS DA PAISAGEM E FRAGILIDADE CONFIGURACIONAL
# Capacitação: Métricas da Paisagem Aplicadas à Fragilidade Configuracional
# ============================================================

# Este script calcula métricas da paisagem para manchas florestais
# e classifica cada mancha em níveis de fragilidade configuracional.

# As métricas usadas são:
# - área da mancha
# - índice de forma
# - área núcleo
# - porcentagem de área núcleo (CAI)
# - distância ao vizinho mais próximo (ENN)

# ------------------------------------------------------------
# 0) LIMPAR O AMBIENTE
# ------------------------------------------------------------

# Remove todos os objetos que estavam carregados no R.
# Isso evita misturar resultados antigos com a análise atual.
rm(list = ls())

# ------------------------------------------------------------
# 1) CARREGAR PACOTES
# ------------------------------------------------------------

# O pacote vectormetrics calcula métricas da paisagem em dados vetoriais.
# O pacote sf trabalha com shapefiles e outros dados espaciais.
# O pacote dplyr organiza e transforma tabelas.
# O pacote tidyr ajuda a reorganizar dados.
# O pacote ggplot2 pode ser usado para gráficos.

library(vectormetrics)
library(sf)
library(dplyr)
library(tidyr)
library(ggplot2)

# ------------------------------------------------------------
# 2) LER O SHAPEFILE DE FLORESTA
# ------------------------------------------------------------

# O arquivo abaixo deve estar na mesma pasta do script.
# Caso esteja em outra pasta, informe o caminho completo.
vetor <- st_read("Rio_Tinto_floresta.shp")

# A coluna Id identifica cada mancha florestal.
# Transformamos em texto para evitar erro na hora de juntar tabelas.
vetor <- vetor %>%
  mutate(Id = as.character(Id))

# Verificar quantas manchas existem no shapefile.
cat("\nNúmero total de fragmentos:", nrow(vetor), "\n")

# Verificar quantas manchas existem por tipo de floresta.
# Aqui, gridcode representa o tipo/classe da floresta.
cat("\nNúmero de fragmentos por gridcode:\n")
print(table(vetor$gridcode))
# ------------------------------------------------------------
# 2.1) VERIFICAR SISTEMA DE COORDENADAS (PROJEÇÃO)
# ------------------------------------------------------------
# Antes de calcular métricas espaciais precisamos verificar
# se o shapefile está em um sistema projetado (metros).
#
# Isso é importante porque:
# - área será calculada em m²;
# - borda de 50 m precisa estar em metros;
# - distância entre manchas (ENN) será em metros.
#
# Sistemas geográficos (latitude/longitude) NÃO são indicados
# para essas análises.

cat("\n==============================\n")
cat("VERIFICAÇÃO DO SISTEMA DE COORDENADAS\n")
cat("==============================\n")

print(st_crs(vetor))

# Verificar se o sistema usa coordenadas geográficas
if (st_is_longlat(vetor)) {
  
  cat("\nATENÇÃO\n")
  cat("Seu arquivo está em latitude/longitude.\n")
  cat("As métricas podem ficar incorretas.\n")
  
  cat("\nReprojetando automaticamente para SIRGAS 2000 / UTM 25S (EPSG:31985)\n")
  
  vetor <- st_transform(
    vetor,
    31985
  )
  
  cat("\nNova projeção:\n")
  print(st_crs(vetor))
  
} else {
  
  cat("\nProjeção adequada detectada.\n")
  cat("As unidades serão interpretadas em metros.\n")
  
}

# Conferir extensão espacial
cat("\nExtensão do arquivo:\n")
print(st_bbox(vetor))

# Conferir unidades
cat("\nUnidade espacial:\n")

if (st_is_longlat(vetor)) {
  
  cat("graus\n")
  
} else {
  
  cat("metros\n")
  
}
# ------------------------------------------------------------
# 3) CALCULAR MÉTRICAS DA PAISAGEM
# ------------------------------------------------------------

# 3.1 Área da mancha
# Calcula a área de cada fragmento.
# class_col = coluna da classe da floresta.
# patch_col = coluna que identifica cada mancha.
area <- vm_p_area(
  landscape = vetor,
  class_col = "gridcode",
  patch_col = "Id"
) %>%
  rename(area = value)

# 3.2 Índice de forma
# Mede o quanto a mancha é regular ou irregular.
# Valores mais altos indicam formas mais irregulares.
forma <- vm_p_shape(
  landscape = vetor,
  class_col = "gridcode",
  patch_col = "Id"
) %>%
  rename(forma = value)

# 3.3 Área núcleo
# Calcula a parte interna da mancha após retirar uma borda de 50 m.
# Essa borda representa a área mais sujeita ao efeito de borda.
core_area <- vm_p_core(
  landscape = vetor,
  class_col = "gridcode",
  patch_col = "Id",
  edge_depth = 50
) %>%
  rename(area_nucleo = value)

# 3.4 CAI - Core Area Index
# Calcula a porcentagem da mancha que corresponde à área núcleo.
# CAI = 0 significa que a mancha não possui área núcleo.
cai <- vm_p_cai(
  landscape = vetor,
  class_col = "gridcode",
  patch_col = "Id",
  edge_depth = 50
) %>%
  rename(perc_area_nucleo = value)

# ------------------------------------------------------------
# 4) CALCULAR ENN - DISTÂNCIA AO VIZINHO MAIS PRÓXIMO
# ------------------------------------------------------------

# ENN significa Euclidean Nearest Neighbor.
# Essa métrica mede a distância, em metros, até a mancha mais próxima
# da mesma classe de floresta.
#
# Importante:
# O cálculo é feito de borda para borda.
# Exemplo: distância da borda de uma mancha até a borda da mancha vizinha.
#
# Como essa métrica pode demorar muito quando existem muitos fragmentos,
# definimos uma regra:
# - até 500 fragmentos: calcula ENN;
# - acima de 500 fragmentos: cria a coluna nndist com NA.

n_fragmentos <- nrow(vetor)

calcular_enn <- n_fragmentos <= 500

if (calcular_enn) {
  
  cat("\nCalculando ENN. Isso pode levar alguns minutos...\n")
  
  tempo_enn <- system.time({
    
    nndist <- vm_p_enn(
      landscape = vetor,
      class_col = "gridcode",
      patch_col = "Id"
    ) %>%
      rename(nndist = value)
    
  })
  
  cat("\nTempo de cálculo do ENN:\n")
  print(tempo_enn)
  
} else {
  
  cat("\nENN não calculado automaticamente porque há mais de 500 fragmentos.\n")
  cat("A coluna nndist será criada com NA.\n")
  
  nndist <- vetor %>%
    st_drop_geometry() %>%
    transmute(
      id = as.character(Id),
      nndist = NA_real_
    )
}

# ------------------------------------------------------------
# 5) JUNTAR TODAS AS MÉTRICAS EM UMA ÚNICA TABELA
# ------------------------------------------------------------

# Cada métrica foi calculada separadamente.
# Agora juntamos tudo em uma única tabela usando a coluna id.

dados_combinados <- area %>%
  select(id, class, area) %>%
  left_join(forma %>% select(id, forma), by = "id") %>%
  left_join(core_area %>% select(id, area_nucleo), by = "id") %>%
  left_join(cai %>% select(id, perc_area_nucleo), by = "id") %>%
  left_join(nndist %>% select(id, nndist), by = "id")

# Mostrar as primeiras linhas da tabela final.
print(head(dados_combinados))

# ------------------------------------------------------------
# 6) CLASSIFICAÇÃO ORIGINAL DA FRAGILIDADE
# ------------------------------------------------------------

# Nesta etapa usamos as regras originais.
# O objetivo é ver quais manchas entram nas classes previstas
# e quais ficam como NC, ou seja, Não Classificadas.

# Siglas:
# AL = Alta fragilidade
# IN = Fragilidade intermediária
# BA = Baixa fragilidade
# NC = Não classificado

fragilidade_original <- dados_combinados %>%
  mutate(
    nivel_fragilidade = case_when(
      
      # Casos sem informação suficiente
      is.na(area) |
        is.na(forma) |
        is.na(perc_area_nucleo) ~ "NC",
      
      # Casos com valores inválidos
      area <= 0 |
        forma <= 0 ~ "NC",
      
      # Alta fragilidade
      area <= 1 &
        perc_area_nucleo == 0 &
        forma >= 1.5 ~ "AL-I",
      
      area > 1 &
        area <= 5 &
        perc_area_nucleo == 0 &
        forma >= 1.5 ~ "AL-II",
      
      area > 1 &
        area <= 5 &
        perc_area_nucleo == 0 &
        forma < 1.5 ~ "AL-III",
      
      area > 1 &
        area <= 5 &
        perc_area_nucleo > 0 &
        forma >= 1.5 ~ "AL-IV",
      
      area > 1 &
        area <= 5 &
        perc_area_nucleo > 0 &
        forma < 1.5 ~ "AL-V",
      
      # Fragilidade intermediária
      area > 5 &
        area <= 50 &
        perc_area_nucleo > 0 &
        forma >= 1.5 ~ "IN-I",
      
      area > 5 &
        area <= 50 &
        perc_area_nucleo > 0 &
        forma < 1.5 ~ "IN-II",
      
      # Baixa fragilidade
      area >= 50 &
        perc_area_nucleo < 25 &
        forma >= 1.5 ~ "BA-I",
      
      area >= 50 &
        perc_area_nucleo < 25 &
        forma < 1.5 ~ "BA-II",
      
      area >= 50 &
        perc_area_nucleo >= 25 &
        forma >= 1.5 ~ "BA-III",
      
      area >= 50 &
        perc_area_nucleo >= 25 &
        forma < 1.5 ~ "BA-IV",
      
      # Tudo que não entrou nas regras acima fica como NC
      TRUE ~ "NC"
    )
  )

# Contar quantas manchas caíram em cada classe.
cat("\nDistribuição dos níveis de fragilidade - classificação original:\n")
print(table(fragilidade_original$nivel_fragilidade))

# ------------------------------------------------------------
# 7) DIAGNÓSTICO DOS FRAGMENTOS NÃO CLASSIFICADOS
# ------------------------------------------------------------

# Filtrar somente os fragmentos NC.
dados_nc <- fragilidade_original %>%
  filter(nivel_fragilidade == "NC")

cat("\nNúmero de fragmentos NC:", nrow(dados_nc), "\n")

# Resumo estatístico dos NC.
# Isso ajuda a entender se os NC são pequenos, grandes,
# com forma regular/irregular ou com/sem área núcleo.
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

# Criar perfis dos NC.
# Aqui agrupamos os NC por:
# - faixa de área
# - faixa de CAI
# - tipo de forma
#
# Isso mostra quais combinações não foram contempladas
# pela classificação original.
# ------------------------------------------------------------
# PERFIL DOS FRAGMENTOS NÃO CLASSIFICADOS (NC)
# ------------------------------------------------------------
# Objetivo:
# Entender quais combinações ficaram fora da classificação
# original e sugerir uma possível classe ecológica.

perfil_nc <- dados_nc %>%
  
  mutate(
    
    # -----------------------------------------
    # Agrupar área
    # -----------------------------------------
    
    classe_area = case_when(
      area <= 1 ~ "<= 1 ha",
      area > 1 & area <= 5 ~ "1–5 ha",
      area > 5 & area <= 15 ~ "5–15 ha",
      area > 15 & area <= 50 ~ "15–50 ha",
      area > 50 ~ "> 50 ha",
      TRUE ~ "sem área"
    ),
    
    # -----------------------------------------
    # Agrupar CAI
    # -----------------------------------------
    
    classe_cai = case_when(
      is.na(perc_area_nucleo) ~ "CAI NA",
      perc_area_nucleo == 0 ~ "CAI = 0",
      perc_area_nucleo > 0 &
        perc_area_nucleo < 25 ~ "CAI 0–25",
      perc_area_nucleo >= 25 ~ "CAI >= 25",
      TRUE ~ "outro CAI"
    ),
    
    # -----------------------------------------
    # Agrupar forma
    # -----------------------------------------
    
    classe_forma = case_when(
      is.na(forma) ~ "forma NA",
      forma < 1.5 ~ "forma < 1.5",
      forma >= 1.5 ~ "forma >= 1.5",
      TRUE ~ "outra forma"
    ),
    
    # -----------------------------------------
    # Sugerir classe potencial
    # -----------------------------------------
    
    potencial_classe = case_when(
      
      area <= 1 &
        perc_area_nucleo == 0 ~
        "AL-I",
      
      area > 5 &
        area <= 50 &
        perc_area_nucleo == 0 &
        forma >= 1.5 ~
        "IN-III",
      
      area > 5 &
        area <= 50 &
        perc_area_nucleo == 0 &
        forma < 1.5 ~
        "IN-IV",
      
      TRUE ~
        "Revisar manualmente"
    )
    
  ) %>%
  
  count(
    classe_area,
    classe_cai,
    classe_forma,
    potencial_classe,
    sort = TRUE
  )

print(perfil_nc)

# Exportar tabela resumida
write.csv(
  perfil_nc,
  "perfil_resumido_NC.csv",
  row.names = FALSE
)

# Salvar os NC para avaliação posterior.
write.csv(
  dados_nc,
  "diagnostico_fragmentos_NC.csv",
  row.names = FALSE
)


# ------------------------------------------------------------
# 8) CLASSIFICAÇÃO AJUSTADA APÓS O DIAGNÓSTICO DOS NC
# ------------------------------------------------------------

# Após observar os NC, ajustamos a classificação.
#
# Ajuste 1:
# Fragmentos com área <= 1 ha e CAI = 0 entram em AL-I,
# independentemente da forma.
#
# Ajuste 2:
# Fragmentos entre 5 e 50 ha, mas sem área núcleo,
# entram em novas subclasses intermediárias:
# IN-III: forma >= 1.5
# IN-IV: forma < 1.5

fragilidade <- dados_combinados %>%
  mutate(
    nivel_fragilidade = case_when(
      
      # Casos sem informação suficiente
      is.na(area) |
        is.na(forma) |
        is.na(perc_area_nucleo) ~ "NC",
      
      # Casos com valores inválidos
      area <= 0 |
        forma <= 0 ~ "NC",
      
      # Alta fragilidade ajustada
      area <= 1 &
        perc_area_nucleo == 0 ~ "AL-I",
      
      area > 1 &
        area <= 5 &
        perc_area_nucleo == 0 &
        forma >= 1.5 ~ "AL-II",
      
      area > 1 &
        area <= 5 &
        perc_area_nucleo == 0 &
        forma < 1.5 ~ "AL-III",
      
      area > 1 &
        area <= 5 &
        perc_area_nucleo > 0 &
        forma >= 1.5 ~ "AL-IV",
      
      area > 1 &
        area <= 5 &
        perc_area_nucleo > 0 &
        forma < 1.5 ~ "AL-V",
      
      # Novas classes intermediárias sem área núcleo
      area > 5 &
        area <= 50 &
        perc_area_nucleo == 0 &
        forma >= 1.5 ~ "IN-III",
      
      area > 5 &
        area <= 50 &
        perc_area_nucleo == 0 &
        forma < 1.5 ~ "IN-IV",
      
      # Classes intermediárias com área núcleo
      area > 5 &
        area <= 50 &
        perc_area_nucleo > 0 &
        forma >= 1.5 ~ "IN-I",
      
      area > 5 &
        area <= 50 &
        perc_area_nucleo > 0 &
        forma < 1.5 ~ "IN-II",
      
      # Baixa fragilidade
      area >= 50 &
        perc_area_nucleo < 25 &
        forma >= 1.5 ~ "BA-I",
      
      area >= 50 &
        perc_area_nucleo < 25 &
        forma < 1.5 ~ "BA-II",
      
      area >= 50 &
        perc_area_nucleo >= 25 &
        forma >= 1.5 ~ "BA-III",
      
      area >= 50 &
        perc_area_nucleo >= 25 &
        forma < 1.5 ~ "BA-IV",
      
      # Caso ainda não entre em nenhuma regra
      TRUE ~ "NC"
    )
  )

cat("\nDistribuição dos níveis de fragilidade - classificação ajustada:\n")
print(table(fragilidade$nivel_fragilidade))

# ------------------------------------------------------------
# 9) JUNTAR A CLASSIFICAÇÃO AO SHAPEFILE ORIGINAL
# ------------------------------------------------------------

# Agora juntamos a tabela final de fragilidade ao shapefile original.
# A união é feita entre:
# - Id do shapefile original
# - id da tabela de métricas

vetor_fragilidade <- vetor %>%
  left_join(
    fragilidade,
    by = c("Id" = "id")
  )

# Garantir que o resultado continua sendo um objeto espacial sf.
vetor_fragilidade <- st_as_sf(vetor_fragilidade)

# ------------------------------------------------------------
# 10) EXPORTAR O SHAPEFILE FINAL
# ------------------------------------------------------------

# Este arquivo poderá ser aberto no QGIS.
# Ele terá as métricas e a coluna nivel_fragilidade.

st_write(
  vetor_fragilidade,
  "fragilidade_paisagem.shp",
  delete_layer = TRUE
)

cat("\nProcessamento concluído!\n")
cat("Arquivo final gerado: fragilidade_paisagem.shp\n")
cat("Tabelas geradas: diagnostico_fragmentos_NC.csv e perfil_resumido_NC.csv\n")