# Fragilidade Configuracional usando vectormetrics

R workflow for calculating landscape metrics and assessing configurational fragility of forest patches using vectormetrics, including diagnostics of unclassified profiles (NC).

---

# Getting Started in R

This tutorial was designed for beginners.

## Understanding the RStudio Interface

RStudio is divided into four main panels:

### 1. Script Editor (Top Left)

Used to write, edit, and save scripts (.R).

Useful commands:

```r
Ctrl + Enter
```
Run selected line(s)

```r
Ctrl + Shift + S
```
Run entire script

```r
Ctrl + Shift + C
```
Comment/uncomment lines

---

### 2. Console (Bottom Left)

Where R executes commands.

Examples:

```r
2 + 2
```

```r
summary(data)
```

```r
head(data)
```

---

### 3. Environment / History (Top Right)

Environment:
Shows objects loaded in memory.

Useful commands:

```r
ls()
```

List objects

```r
rm(list = ls())
```

Clear workspace

```r
object.size(vetor)
```

Check object size

---

### 4. Files / Plots / Packages / Help (Bottom Right)

Files → navigate folders

Plots → display graphs

Packages → manage packages

Help → access documentation

Useful commands:

```r
help(vm_p_area)
```

```r
?st_read
```

```r
library(sf)
```

---

# Useful Commands for This Tutorial

Set working directory:

```r
setwd("C:/Users/ENCOM/Documents/data_aula")
```

Check current directory:

```r
getwd()
```

Install packages:

```r
install.packages("sf")
```

Load packages:

```r
library(sf)
```

Read shapefile:

```r
st_read("FLORESTA_2023.shp")
```

View table:

```r
View(vetor)
```

Check structure:

```r
str(vetor)
```

Check missing values:

```r
colSums(is.na(vetor))
```

---

# Workflow

1. Load spatial data
2. Calculate landscape metrics
3. Classify configurational fragility
4. Diagnose NC profiles
5. Export outputs

---

R workflow for calculating landscape metrics and assessing configurational fragility of forest patches using vectormetrics, including diagnostics of unclassified profiles (NC).

## Objectives

This repository provides a reproducible workflow to:

- Calculate landscape metrics from vector data;
- Estimate patch area;
- Compute shape index;
- Calculate core area and Core Area Index (CAI);
- Measure nearest-neighbor distance (ENN);
- Classify configurational fragility;
- Diagnose unclassified profiles (NC).

## Metrics

| Metric | Description |
|--------|-------------|
| Area | Patch area |
| Shape | Shape complexity |
| Core Area | Interior habitat |
| CAI | Core Area Index |
| ENN | Euclidean Nearest Neighbor |

## Conceptual model

```mermaid
flowchart TD
    A[Forest patches] --> B[Landscape metrics]
    B --> C[Area]
    B --> D[Shape index]
    B --> E[Core area]
    B --> F[CAI]
    B --> G[ENN]

    C --> H[Configurational fragility]
    D --> H
    E --> H
    F --> H
    G --> H

    H --> I[High fragility]
    H --> J[Intermediate fragility]
    H --> K[Low fragility]
    H --> L[NC diagnosis]
```md
## Outputs

- Landscape metrics table
- Fragility classification
- NC diagnostics
- Final shapefile

## Packages

- vectormetrics
- sf
- dplyr
- tidyr
- ggplot2

## Author

Jessyca Janyny de Oliveira Saraiva-Maia
