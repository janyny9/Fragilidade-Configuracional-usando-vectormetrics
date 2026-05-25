# Fragilidade Configuracional usando vectormetrics

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
