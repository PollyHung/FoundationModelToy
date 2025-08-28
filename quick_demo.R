#!/usr/bin/env R
# Foundation Model + Digital Twin Quick Demo
# Optimized for presentation on MacBook Pro M4
# Date: August 28, 2025

setwd("~/Desktop/FoundationModel/")

cat("=== FOUNDATION MODEL + DIGITAL TWIN PRESENTATION ===\n")
cat("Target: Ovarian Cancer Survival & Platinum Resistance\n")
cat("Platform: MacBook Pro M4 optimized\n\n")

# Check and install required packages
required_packages <- c("randomForest", "survival", "ggplot2", "dplyr")
for(pkg in required_packages) {
  if(!require(pkg, character.only = TRUE, quietly = TRUE)) {
    cat("Installing", pkg, "...\n")
    install.packages(pkg, repos = "https://cran.r-project.org/", quiet = TRUE)
    library(pkg, character.only = TRUE)
  }
}

# Set seed for reproducibility
set.seed(42)

cat("Step 1: Generating simulated ovarian cancer cohort...\n")

# Generate realistic ovarian cancer dataset
n_patients <- 150  # Manageable size for demo
n_genes <- 100     # Key cancer genes

# Patient metadata
patients <- data.frame(
  id = paste0("OV", sprintf("%03d", 1:n_patients)),
  age = round(rnorm(n_patients, 65, 10)),
  stage = sample(c("III", "IV"), n_patients, replace = TRUE, prob = c(0.7, 0.3)),
  subtype = sample(c("HGSOC", "CCOC"), n_patients, replace = TRUE, prob = c(0.75, 0.25)),
  ca125 = round(rlnorm(n_patients, 6, 1)),
  brca_status = sample(c("Wild-type", "BRCA_mut"), n_patients, replace = TRUE, prob = c(0.8, 0.2)),
  stringsAsFactors = FALSE
)

# Simulate gene expression (key cancer pathways)
gene_names <- c("TP53", "BRCA1", "BRCA2", "PIK3CA", "PTEN", "MYC", "CCNE1", "RB1", 
               paste0("GENE_", sprintf("%02d", 9:n_genes)))

# Create realistic expression patterns
expression_data <- matrix(rnorm(n_patients * n_genes, 5, 2), nrow = n_genes, ncol = n_patients)
rownames(expression_data) <- gene_names
colnames(expression_data) <- patients$id

# Add biological signal
hgsoc_idx <- which(patients$subtype == "HGSOC")
ccoc_idx <- which(patients$subtype == "CCOC")

# HGSOC pattern (high TP53, BRCA pathway)
expression_data[1:10, hgsoc_idx] <- expression_data[1:10, hgsoc_idx] + rnorm(10 * length(hgsoc_idx), 1.5, 0.3)

# CCOC pattern (high PIK3CA/mTOR)  
expression_data[11:20, ccoc_idx] <- expression_data[11:20, ccoc_idx] + rnorm(10 * length(ccoc_idx), 1.5, 0.3)

# Generate copy number variations
cnv_arms <- paste0("chr", rep(1:22, each = 2), c("p", "q"))
cnv_data <- matrix(rnorm(n_patients * length(cnv_arms), 0, 0.3), 
                   nrow = length(cnv_arms), ncol = n_patients)
rownames(cnv_data) <- cnv_arms
colnames(cnv_data) <- patients$id

cat("Generated data for", n_patients, "patients\n")
cat("HGSOC:", length(hgsoc_idx), "| CCOC:", length(ccoc_idx), "\n")

cat("\nStep 2: Generating clinical outcomes...\n")

# Realistic survival outcomes
base_survival <- ifelse(patients$subtype == "CCOC", 18, 26)
age_effect <- -0.3 * scale(patients$age)[,1]
stage_effect <- ifelse(patients$stage == "IV", -8, 0)
brca_effect <- ifelse(patients$brca_status == "BRCA_mut", 6, 0)

# Gene signature effect
gene_signature <- colMeans(expression_data[1:20, ])
gene_effect <- scale(gene_signature)[,1] * 4

# CNV instability
cnv_instability <- apply(abs(cnv_data), 2, mean)
cnv_effect <- -scale(cnv_instability)[,1] * 3

# Combine effects
total_survival <- base_survival + age_effect + stage_effect + brca_effect + gene_effect + cnv_effect + rnorm(n_patients, 0, 4)
survival_months <- pmax(2, total_survival)

# Death events
death_prob <- 1 / (1 + exp((survival_months - 24) / 8))
death_event <- rbinom(n_patients, 1, death_prob)

# Platinum resistance 
resist_base <- ifelse(patients$subtype == "CCOC", 0.65, 0.35)
resist_brca <- ifelse(patients$brca_status == "BRCA_mut", -0.3, 0)
resist_gene <- tanh(gene_effect * 0.1)

resistance_prob <- pmax(0.1, pmin(0.9, resist_base + resist_brca + resist_gene))
platinum_resistant <- rbinom(n_patients, 1, resistance_prob)

# Combine outcomes
outcomes <- data.frame(
  id = patients$id,
  survival_months = round(survival_months, 1),
  death_event = death_event,
  platinum_resistant = platinum_resistant,
  stringsAsFactors = FALSE
)

# Merge all data
full_data <- merge(patients, outcomes, by = "id")

cat("Mean survival:", round(mean(full_data$survival_months), 1), "months\n")
cat("Platinum resistance rate:", round(mean(full_data$platinum_resistant), 2), "\n")

cat("\nStep 3: Building foundation model...\n")

# Create integrated feature matrix
clinical_features <- model.matrix(~ age + stage + subtype + brca_status, data = full_data)[,-1]
gene_features <- t(expression_data[1:50, ])  # Top 50 genes
cnv_features <- t(cnv_data[1:20, ])          # Top 20 CNV regions

X <- cbind(clinical_features, gene_features, cnv_features)
X[is.na(X)] <- 0

cat("Feature matrix:", nrow(X), "samples x", ncol(X), "features\n")

# Split data for validation
train_idx <- sample(1:nrow(X), floor(0.7 * nrow(X)))
test_idx <- setdiff(1:nrow(X), train_idx)

X_train <- X[train_idx, ]
X_test <- X[test_idx, ]

cat("\nStep 4: Training survival prediction model...\n")

# Survival model
y_survival_train <- full_data$survival_months[train_idx]
y_survival_test <- full_data$survival_months[test_idx]

survival_model <- randomForest(X_train, y_survival_train, ntree = 100, mtry = sqrt(ncol(X_train)))
survival_pred <- predict(survival_model, X_test)

survival_mae <- mean(abs(survival_pred - y_survival_test))
survival_cor <- cor(survival_pred, y_survival_test)

cat("Survival Model Performance:\n")
cat("  MAE:", round(survival_mae, 2), "months\n")
cat("  Correlation:", round(survival_cor, 3), "\n")

cat("\nStep 5: Training platinum resistance model...\n")

# Resistance model
y_resist_train <- as.factor(full_data$platinum_resistant[train_idx])
y_resist_test <- full_data$platinum_resistant[test_idx]

resistance_model <- randomForest(X_train, y_resist_train, ntree = 100, mtry = sqrt(ncol(X_train)))
resistance_pred <- predict(resistance_model, X_test, type = "prob")[,2]

# Calculate AUC manually
resistance_pred_sorted <- sort(resistance_pred, decreasing = TRUE)
n_pos <- sum(y_resist_test == 1)
n_neg <- sum(y_resist_test == 0)

if(n_pos > 0 & n_neg > 0) {
  auc <- 0
  for(i in 1:length(resistance_pred)) {
    threshold <- resistance_pred[i]
    tp <- sum(resistance_pred >= threshold & y_resist_test == 1)
    fp <- sum(resistance_pred >= threshold & y_resist_test == 0)
    if(i == 1) {
      sensitivity <- tp / n_pos
      specificity <- 1 - fp / n_neg
      prev_sens <- sensitivity
      prev_spec <- specificity
    } else {
      sensitivity <- tp / n_pos
      specificity <- 1 - fp / n_neg
      auc <- auc + (prev_sens + sensitivity) * abs(prev_spec - specificity) / 2
      prev_sens <- sensitivity
      prev_spec <- specificity
    }
  }
} else {
  auc <- 0.5
}

resistance_accuracy <- mean((resistance_pred > 0.5) == y_resist_test)

cat("Resistance Model Performance:\n")
cat("  AUC:", round(auc, 3), "\n")
cat("  Accuracy:", round(resistance_accuracy, 3), "\n")

cat("\nStep 6: Digital Twin demonstration...\n")

# Create digital twin function
create_digital_twin <- function(patient_id) {
  idx <- which(full_data$id == patient_id)
  if(length(idx) == 0) return(NULL)
  
  patient_data <- full_data[idx, ]
  patient_features <- X[idx, , drop = FALSE]
  
  # Predictions
  pred_survival <- predict(survival_model, patient_features)
  pred_resistance <- predict(resistance_model, patient_features, type = "prob")[,2]
  
  # Risk stratification
  risk_level <- ifelse(pred_survival < 18, "HIGH", ifelse(pred_survival < 30, "MEDIUM", "LOW"))
  
  # Treatment recommendation
  treatment_rec <- ifelse(pred_resistance > 0.6, 
                         "Consider non-platinum therapy",
                         "Platinum-based therapy recommended")
  
  return(list(
    patient_id = patient_id,
    clinical_info = patient_data,
    predictions = list(
      survival = as.numeric(pred_survival),
      resistance_prob = as.numeric(pred_resistance),
      risk_level = risk_level,
      treatment = treatment_rec
    ),
    actual_outcomes = list(
      survival = patient_data$survival_months,
      resistance = ifelse(patient_data$platinum_resistant == 1, "RESISTANT", "SENSITIVE")
    )
  ))
}

# Demo with sample patients
demo_patients <- sample(full_data$id, 3)
for(pid in demo_patients) {
  twin <- create_digital_twin(pid)
  
  cat("\n=== DIGITAL TWIN REPORT ===\n")
  cat("Patient:", pid, "\n")
  cat("Age:", twin$clinical_info$age, "| Stage:", twin$clinical_info$stage, 
      "| Subtype:", twin$clinical_info$subtype, "\n")
  cat("BRCA:", twin$clinical_info$brca_status, "| CA-125:", twin$clinical_info$ca125, "\n\n")
  
  cat("PREDICTIONS:\n")
  cat("  Survival:", round(twin$predictions$survival, 1), "months (", twin$predictions$risk_level, " risk)\n")
  cat("  Platinum Resistance:", round(twin$predictions$resistance_prob, 3), "\n")
  cat("  Treatment:", twin$predictions$treatment, "\n\n")
  
  cat("ACTUAL OUTCOMES:\n") 
  cat("  Survival:", twin$actual_outcomes$survival, "months\n")
  cat("  Resistance:", twin$actual_outcomes$resistance, "\n")
  cat("================================\n")
}

cat("\nStep 7: Key insights and clinical applications...\n")

# Feature importance
surv_importance <- importance(survival_model)[,1]
resist_importance <- importance(resistance_model)[,2]

top_survival_features <- names(sort(surv_importance, decreasing = TRUE)[1:5])
top_resistance_features <- names(sort(resist_importance, decreasing = TRUE)[1:5])

cat("\nTop Survival-related Features:\n")
for(i in 1:length(top_survival_features)) {
  cat(" ", i, ". ", top_survival_features[i], "\n", sep = "")
}

cat("\nTop Resistance-related Features:\n")
for(i in 1:length(top_resistance_features)) {
  cat(" ", i, ". ", top_resistance_features[i], "\n", sep = "")
}

cat("\n=== FOUNDATION MODEL + DIGITAL TWIN DEMO COMPLETE ===\n\n")

cat("KEY ACHIEVEMENTS:\n")
cat("• Multi-modal data integration (clinical + genomic)\n")
cat("• Survival prediction with", round(survival_cor, 3), "correlation\n") 
cat("• Platinum resistance prediction with", round(auc, 3), "AUC\n")
cat("• Patient-specific digital twins for personalized medicine\n")
cat("• Memory-optimized for MacBook Pro M4\n\n")

cat("CLINICAL APPLICATIONS:\n")
cat("• Personalized prognosis and treatment selection\n")
cat("• Early identification of platinum-resistant patients\n")
cat("• Biomarker discovery from feature importance\n")
cat("• Decision support for oncologists\n")
cat("• Stratification for clinical trials\n\n")

cat("NEXT STEPS:\n")
cat("• Integration with real QueenMary data\n")
cat("• Validation on external cohorts\n")
cat("• Deep learning architecture implementation\n")
cat("• Clinical deployment planning\n")
cat("• Regulatory pathway development\n\n")

cat("=== READY FOR PRESENTATION ===\n")

# Save results
results <- list(
  dataset = full_data,
  models = list(survival = survival_model, resistance = resistance_model),
  performance = list(
    survival_mae = survival_mae,
    survival_correlation = survival_cor,
    resistance_auc = auc,
    resistance_accuracy = resistance_accuracy
  ),
  feature_importance = list(
    survival = top_survival_features,
    resistance = top_resistance_features
  )
)

save(results, file = "demo_results.RData")
cat("Results saved to demo_results.RData\n")