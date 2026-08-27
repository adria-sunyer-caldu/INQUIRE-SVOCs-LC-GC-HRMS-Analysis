# INQUIRE-SVOCs-LC-GC-HRMS-Analysis

Target and nontarget LC-HRMS/GC-HRMS analysis of semi-volatile organic
compounds (SVOCs) in indoor/outdoor air across Europe, using PDMS foam
passive samplers — INQUIRE project.

This repository contains the full analysis pipeline behind the associated
manuscript (citation to be added upon publication), organized by pipeline
stage so each folder can be run largely independently once its inputs are
available.

## Data availability

Raw and processed data files (polished target/annotation datasets, the
pikme hazard database subset, AdductFinder/InSourceFinder outputs, etc.)
are deposited separately on Zenodo: **[DOI link to be added]**.

Scripts in this repository expect those files to be present in a local
working directory — each script has a `data_dir <- "path/to/data"` (or
similarly named) variable near the top that you should point at wherever
you've placed the downloaded data.

## Repository structure and run order

Folders are numbered in roughly the order they depend on each other's
outputs. Within `09_toxicity`, the pikme-based scripts also require a
separate hazard database (pikme) subset — see comments inside those
scripts for details.

| Folder | Contents | Depends on |
|---|---|---|
| `01_datasets_preparation` | Rename/merge raw RT & field-blank files (POS+NEG); remove adduct/in-source-fragment features; produce the final polished Level 1–2 (confirmed) and Level 1–5 (all annotation levels) LC/GC datasets | Raw MS-DIAL exports (Zenodo) |
| `02_qc_validation` | RT stability, field blank levels, internal-standard normalization QC (RSD heatmap + before/after normalization) | `01_datasets_preparation` outputs |
| `03_total_burden` | Total chemical burden per sample/household, LC and GC, by country; fold-change and raincloud summary figures | `01_datasets_preparation` outputs |
| `04_target_analysis` | Compound-class indoor/outdoor enrichment, LC-vs-GC identity overlap, merged class-panel detection-frequency figures, named-compound violin plots | `01_datasets_preparation` outputs |
| `05_nontarget_analysis` | Full nontarget feature prevalence/prioritization (paired indoor/outdoor ratio), Kendrick mass defect, NAP-based molecular characterization (Van Krevelen, DBE, halogenation) | `01_datasets_preparation` outputs |
| `06_pca` | PCA of LC/GC data, both for confirmed targets/annotations only and for the full nontarget feature set | `01_datasets_preparation` outputs |
| `07_hca` | Interactive hierarchical clustering heatmaps (Shiny apps), LC and GC. Snapshot of the deployed apps; live versions hosted on SciLifeLab Serve | `01_datasets_preparation` outputs |
| `08_correlations` | Pairwise Spearman correlation and Fisher's exact co-occurrence networks between compounds, plus sample-level detection heatmaps for rare co-occurring compounds | `01_datasets_preparation` outputs |
| `09_toxicity` | Hazard/EDC characterization using the pikme database (DTXSID retrieval, hazard-score merging, indoor/outdoor hazard statistics and figures) | `01_datasets_preparation` outputs + pikme database subset (Zenodo) |
| `10_annotation_confidence` | Annotation confidence-level (Schymanski/Koelmel scale) distribution, LC and GC | `01_datasets_preparation` outputs + NAP cross-reference file |
| `utils` | Standalone Python helpers for retrieving InChIKeys/CAS/SMILES/molecular formula from PubChem, used during compound identification | none (run independently as needed) |

## Interactive visualizations

Live, interactive versions of the hierarchical clustering heatmaps:
- LC-HRMS: [link to be added]
- GC-HRMS: [link to be added]

## Requirements

**R** (≥ 4.x recommended). Key packages used across scripts:
`data.table`, `dplyr`, `tidyr`, `stringr`, `ggplot2`, `readxl`, `writexl`,
`scales`, `patchwork`, `igraph`, `ggraph`, `pheatmap`, `ComplexHeatmap`,
`InteractiveComplexHeatmap`, `circlize`, `arrow`, `ctxR`, `shiny`.
Install via `install.packages()`; a few scripts install missing packages
automatically on first run.

**Python** (≥ 3.9) for the `utils` scripts: `pandas`, `requests`, `openpyxl`.

## Notes on reproducibility

- Every script's working/data directory is a placeholder
  (`"path/to/data"`) — edit this at the top of each script before running.
- Scripts are designed to be run top-to-bottom within their file; several
  read a previous script's CSV output rather than recomputing it, so
  running out of order within a folder may fail with a missing-file error.
- One script (`retrieve_DTXSID_GC` step, folder `09_toxicity`) requires a
  free EPA CTX API key, supplied via the environment variable
  `CTX_API_KEY` (never hardcoded in the script itself).

## License

All content in this repository — code and data alike — is released under
the [Creative Commons Attribution 4.0 International License (CC-BY 4.0)](https://creativecommons.org/licenses/by/4.0/).
You are free to share and adapt this material for any purpose, including
commercially, as long as you give appropriate credit.

**Attribution:** Adrià Sunyer Caldú, Stockholm University — INQUIRE project.

Data deposited separately on Zenodo is likewise released under CC-BY 4.0.

## Citation

If you use this code or data, please give credit to:
Adrià Sunyer Caldú, Stockholm University — [paper citation to be added upon publication]
[Zenodo software DOI to be added]

## Contact

Adrià Sunyer Caldú — Stockholm University
