# medicalcoder: A Unified and Longitudinally Aware Framework for ICD-Based Comorbidity Assessment in R

Presentation materials for [R/Medicine 2026](https://rconsortium.github.io/RMedicine_website/)

**Accepted for a Regular Talk**

* May 8, 2026 at 2:06 PM Eastern Daylight Time
* 20 minutes (including Q&A)

## Abstract

Comorbidity algorithms derived from International Classification of Diseases (ICD) codes are central to risk adjustment and cohort characterization in clinical research. However, existing implementations often fragment across packages, inconsistently handle mixed ICD-9 and ICD-10 data, and typically rely on encounter-level aggregation that may under-ascertain chronic disease burden.

We present medicalcoder, an R package providing a unified, longitudinally aware framework for applying multiple variants of the Charlson, Elixhauser, and Pediatric Complex Chronic Conditions algorithms. The package includes an internal ICD database, supports full and compact codes, accommodates mixed ICD versions within a dataset, and integrates present-on-admission and primary diagnosis indicators.

Unlike encounter-level approaches that simply aggregate flags, medicalcoder implements cumulative longitudinal methods that propagate qualifying diagnoses forward in time, increasing sensitivity and improving detection of disease severity. The package is self-contained (R ≥ 3.5.0) and designed for portability in restricted computing environments while dynamically leveraging modern R workflows when available.

This talk will demonstrate longitudinal sensitivity gains, mixed-version handling, and practical workflows for reproducible comorbidity assessment in real-world EHR data.
