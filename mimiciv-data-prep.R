################################################################################
# file: mimiciv-data-prep.R
#
# Objective:
#
#   import the MIMIC-IV v3.1 data and build an analysis ready data.frame
#   called mimiciv
#
# Prereqs:
#
#   A local copy of the MIMIC-IV v3.1 data is available
#
#   get the data from
#   https://physionet.org/content/mimiciv/3.1/
#
#   The path to the data set is stored in a system environment variable
#   MIMICIVDATA
#
#   R Namespaces:
#     data.table
#     arrow
#
# Output:
#
#   mimiciv.feather is a data.frame (data.table) with the following columns
#
#   * subject_id:  integer value from MIMIC
#
#   * hadmd_id:    hospital admission id, integer value from MIMIC.  Note: these
#                  IDs are note sequential within a patient record.
#
#   * dx:          an integer column of 0s and 1s.  0 = icd_code is a procedure
#                  code, 1 = icd_code is a diagnosis code
#
#   * icd_code:    character vector of compact ICD codes
#
#   * icd_version: an integer column with values 9L and 10L indicating if the
#                  icd_code is an ICD-9 or ICD-10 code.
#
#   * age:         age, in years, for the patient for the hadmd_id
#
#   * poa:         present-on-admission flag.  This was created to support the
#                  medicalcoder examples.  Procedure codes have a chartdate and
#                  that was used relative to the admittime to define poa for
#                  procedure codes.  Diagnostic codes do not have a chartdate.
#                  A poa flag was created probabilistically based on the code
#                  seq_number
#
#   * pdx:         integer column: 1 = diagnosis code is the primary diagnosis,
#                  0 = diagnosis code is a secondary diagnosis for the
#                  encounter
#
#   * enc_seq      a constructed encounter sequence variable.  Using the
#                  subject_id and admittime, this variable denotes the first,
#                  second, third, ..., encounter within a subject_id
#
################################################################################
set.seed(960122) # GoAvsGo

# import the data needed data files
# * admissions
# * patients
# * diagnoses_icd
# * procedure_icd
mimicivdata <-
  list.files(
    path = file.path(Sys.getenv("MIMICIVDATA"), "hosp"),
    pattern = "(admissions|patients|.+_icd)\\.csv\\.gz",
    full.names = TRUE
  )
names(mimicivdata) <- sub("\\.csv\\.gz$", "", basename(mimicivdata))

mimicivdata <- lapply(mimicivdata, data.table::fread)

# build an age data set
# age will be in years and defined as the floor of the differnce between the
# admission date and January 1 of the anchor_year
mimicivdata[["ages"]] <-
  merge(
    x = mimicivdata[["admissions"]][, .(subject_id, hadm_id, admittime)],
    y = mimicivdata[["patients"]][,   .(subject_id, anchor_age, anchor_year)],
    all = FALSE,
    by = "subject_id"
  )

mimicivdata[["ages"]][
  , anchor_date := data.table::as.IDate(sprintf("%d-01-01", anchor_year))
]

mimicivdata[["ages"]][
  , admit_date := data.table::as.IDate(admittime)
]

# define age as the number of
mimicivdata[["ages"]][
  , age := floor(anchor_age + as.numeric(difftime(admit_date, anchor_date), units = "days") / 365.2425)
]


# build the one data set
mimicivDT <-
  merge(
    x = mimicivdata[["patients"]][, .(subject_id, anchor_age, anchor_year)],
    y = mimicivdata[["admissions"]][, .(subject_id, hadm_id, admittime)],
    all = TRUE,
    by = c("subject_id")
  )

mimicivDT <-
  merge(
    x = mimicivDT,
    y = data.table::rbindlist(
          list(
            dx = mimicivdata[["diagnoses_icd"]],
            pr = mimicivdata[["procedures_icd"]]
          ),
          idcol = "dx", use.names = TRUE, fill = TRUE
      ),
    all = TRUE,
    by = c("subject_id", "hadm_id")
  )

mimicivDT <-
  merge(
    x = mimicivDT,
    y = mimicivdata[["ages"]][, .(subject_id, hadm_id, age)],
    all.x = TRUE,
    by = c("subject_id", "hadm_id")
  )

# We'll want the diagnosis/procedures flag to be an integer 1 for diagnosis 0
# for procedure
mimicivDT[, dx := as.integer(dx == "dx")]

################################################################################
# Create Present-on-admission flags
# extend the data set to have poa and pdx flags
#
# Procedure ICD codes have a chartdate so use that to define poa relative to
# admittime
mimicivDT[, poa := as.integer(chartdate < data.table::as.IDate(admittime))]

# Diagnostic codes do not have a date-time associated.
# Create a poa flag.
# Assume the probability of the diagnosis code is poa is 2^(1 - seq_num)
set.seed(42)
mimicivDT[dx == 1 & is.na(poa), poa := as.integer(runif(.N) < 2^(1 - seq_num))]

# Let's assume `seq_num == 1` is the primary diagnosis
mimicivDT[dx == 1, pdx := as.integer(seq_num == 1)]

################################################################################
# Encounters Sequence
# set keys and order the data by subject id, admittime, hadm_id
data.table::setkey(mimicivDT, subject_id, admittime, hadm_id)

# set an encounter sequence variable. This works because the data has been
# sorted by subject_id, admittime.  NOTE: admittime can be used in the
# calls to medicalcoder::comorbidities() but it there is additional
# overhead and computational expense when sorting and joining by POSIXct
# variable.  The enc_seq achieves the same utility with lower computational
# overhead.
mimicivDT[, enc_seq := cumsum(!duplicated(hadm_id)), by = .(subject_id)]

# omit columns not needed for examples
mimicivDT[, anchor_age := NULL]
mimicivDT[, anchor_year := NULL]
mimicivDT[, chartdate := NULL]
mimicivDT[, seq_num := NULL]
mimicivDT[, admittime := NULL]

################################################################################
# Save to disk
arrow::write_feather(x = mimicivDT, sink = "mimiciv.feather")

################################################################################
#                                 End of File                                  #
################################################################################
