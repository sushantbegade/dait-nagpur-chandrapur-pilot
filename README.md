# DAIT Pilot: Compression-Stratified Predictive Performance
## Nagpur–Chandrapur Palaeolithic Dataset

[![DOI (Code)](https://zenodo.org/badge/DOI/10.5281/zenodo.22806508.svg)](https://doi.org/10.5281/zenodo.22806508)
[![DOI (Data)](https://zenodo.org/badge/DOI/10.5281/zenodo.22806539.svg)](https://doi.org/10.5281/zenodo.22806539)

Reproducible research compendium for Section 6 ("Illustrative Application")
of Begade, S. "Deep-Time Archaeological Inference Theory: A General Theory
of Uncertainty, Equifinality, and the Limits of Archaeological Knowledge"
(manuscript in preparation, target: Journal of Archaeological Method and
Theory).

## What this tests

DAIT's Equation 17 predicts that predictive spatial model accuracy declines
with cumulative informational compression (Model Accuracy ∝ Observability
= 1−C). This compendium builds a provisional compression proxy from an
independently compiled site inventory (Begade 2026; Begade & Sahu 2026;
Begade 2027), fits a MaxEnt model against time-stable environmental
covariates, and tests whether model accuracy (AUC) declines across
Low/Moderate/High compression tiers.

**Result:** directionally consistent with the prediction at ~150m spatial
resolution (AUC: Low=0.789, Moderate=0.770, High=0.704), but differences
did not reach conventional statistical significance (DeLong's test,
all p > 0.10). At coarser ~300m resolution, the predicted ordering did
not hold, diagnosed as an artifact of spatial aggregation blurring
fine-scale geological signal (see manuscript Section 6.4–6.5 for full
interpretation and limitations).

## Data sources

- `data/raw/site_data/` — Nagpur–Chandrapur Palaeolithic site inventory
  (197 sites), compiled by S. Begade from published survey/excavation
  reports (see `Primary.Reference` field in the site table and the
  manuscript's References list).
- `data/raw/DEM/`, `Geomorphology/`, `Lithology/`, `Rivers/`, `Waterbody/`
  — derived from public Geological Survey of India (Bhukosh) and
  DEM sources. See `data/raw/SOURCES.md` for exact source, version, and
  access-date details, and for licensing/redistribution notes.

## Requirements

R ≥ 4.3. Package versions locked via `renv` — see `renv.lock`.

```r
install.packages("renv")
renv::restore()
```

## Reproducing the analysis

Run scripts in order from the project root:

```r
source("scripts/01_load_clean_sites.R")
source("scripts/02_compression_proxy.R")
source("scripts/03_prepare_covariates.R")              # ~300m resolution (initial pilot)
source("scripts/04_extract_covariates.R")
source("scripts/05_run_maxent.R")
source("scripts/06_stratified_evaluation.R")           # Result: predicted ordering NOT observed
source("scripts/07_covariates_finegrid.R")             # ~150m resolution (sensitivity check)
source("scripts/08_extract_finegrid.R")
source("scripts/09_finegrid_maxent_and_evaluation.R")  # Result: predicted ordering observed, n.s.
source("scripts/10_delong_tests.R")                    # Pairwise significance tests
```

Or, once consolidated:
```r
source("scripts/run_all.R")
```

## Why two resolutions are reported

The ~300m run was the original pilot. The lithology covariate (expected,
on taphonomic grounds, to carry compression-relevant signal — see
manuscript Section 10) returned a zero coefficient at this resolution,
diagnosed as an artifact of spatial aggregation blurring fine-scale
geological boundaries. The ~150m re-run was undertaken as a pre-specified
methodological correction for this reason, not in response to the
stratified result itself. Both results are reported transparently in
the manuscript (Section 6.4) rather than only the preferred outcome.

## Known limitations (see manuscript Section 6.5 for full discussion)

1. Compression proxy (CT_raw) is a hand-built ordinal composite of six
   site-record fields (depositional context, locational precision,
   recovery method, and three reporting-completeness indicators), not
   a direct measurement of DAIT's compression function (Equation 3).
   Tertile-based tiers are used, not the theory's absolute 5-class
   boundaries (Table 3), which the proxy's resolution does not support.
2. The pilot is underpowered (N=40–80 sites per tier) to detect effects
   of the magnitude observed here at conventional significance levels.
3. Partial overlap between compression-proxy inputs (site type) and
   model covariates (geomorphology) risks some shared-information
   confound; not fully resolved in this pilot. A properly independent
   compression measure is a design requirement for the follow-up
   measurement paper ("Measuring Deep-Time Compression").

## Repository structure
DAIT/
├── README.md
├── LICENSE
├── data/
│ ├── raw/ # original source files (see SOURCES.md)
│ └── derived/ # script outputs (compression scores, covariate
│ stacks, model objects, extracted covariates)
├── scripts/ # 01-10, run in numeric order (see above)
├── outputs/
│ ├── figures/
│ └── tables/ # stratified AUC results, methods documentation
└── renv.lock # locked package versions

## Citation

If you use this code or data, please cite both records:
Begade, S. (2026). Compression-Stratified Predictive Modelling of
Palaeolithic Sites in the Nagpur–Chandrapur Region: Code for the
Deep-Time Archaeological Inference Theory (DAIT) Pilot Application
[Software]. Zenodo. https://doi.org/10.5281/zenodo.22806508

Begade, S. (2026). Compression-Stratified Predictive Modelling of
Palaeolithic Sites in the Nagpur–Chandrapur Region: Data for the
Deep-Time Archaeological Inference Theory (DAIT) Pilot Application
[Dataset]. Zenodo. https://doi.org/10.5281/zenodo.22806539


And the manuscript this compendium supports (citation to be updated
upon publication):
Begade, S. (in preparation). Deep-Time Archaeological Inference Theory:
A General Theory of Uncertainty, Equifinality, and the Limits of
Archaeological Knowledge. Journal of Archaeological Method and Theory.


## License

Code: MIT License (see `LICENSE`).
Data and documentation: Creative Commons Attribution 4.0 International
(CC-BY 4.0), consistent with the Zenodo data deposit.