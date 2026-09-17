# DAIT Pilot: Compression-Stratified Predictive Performance
## Nagpur–Chandrapur Palaeolithic Dataset

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
all p > 0.10). See manuscript Section 6.5 for full interpretation and
limitations.

## Data sources

- `data/raw/site_data/` — Nagpur–Chandrapur Palaeolithic site inventory
  (197 sites), compiled by S. Begade from published survey/excavation
  reports (see Primary.Reference field and manuscript References).
- `data/raw/DEM/`, `Geomorphology/`, `Lithology/`, `Rivers/`, `Waterbody/`
  — derived from public Geological Survey of India (Bhukosh) and
  SRTM/equivalent DEM sources. Original source licensing should be
  confirmed before redistribution; not included in the archived Zenodo
  package if licensing restricts re-hosting — see `data/raw/SOURCES.md`.

## Requirements

R ≥ 4.3. Package versions locked via `renv` — see `renv.lock`.

```r
install.packages("renv")
renv::restore()
```

## Reproducing the analysis

Run scripts in order from project root:

```r
source("scripts/01_load_clean_sites.R")
source("scripts/02_compression_proxy.R")
source("scripts/03_prepare_covariates.R")        # ~300m resolution (initial)
source("scripts/04_extract_covariates.R")
source("scripts/05_run_maxent.R")
source("scripts/06_stratified_evaluation.R")     # Result: predicted ordering NOT observed
source("scripts/07_covariates_finegrid.R")       # ~150m resolution (sensitivity check)
source("scripts/08_extract_finegrid.R")
source("scripts/09_finegrid_maxent_and_evaluation.R")  # Result: predicted ordering observed, ns
source("scripts/10_delong_tests.R")              # Pairwise significance tests
```

Or, once all scripts finalized:
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
   site-record fields, not a direct measurement of DAIT's compression
   function (Equation 3). Tertile-based tiers, not the theory's absolute
   5-class boundaries (Table 3).
2. Pilot is underpowered (N=40-80 per tier) to detect effects of the
   magnitude observed at conventional significance.
3. Partial overlap between compression-proxy inputs (site type) and
   model covariates (geomorphology) risks some shared-information
   confound; not fully resolved in this pilot.

## Citation

Begade, S. (2026, in prep). Deep-Time Archaeological Inference Theory.
[Compendium DOI to be added upon Zenodo archival.]

## License

Code: MIT License (see LICENSE). Data licensing per source — see
`data/raw/SOURCES.md`.