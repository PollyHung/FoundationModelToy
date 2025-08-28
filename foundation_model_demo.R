#!/usr/bin/env Rscript
# Foundation Model + Digital Twin Toy Demonstration
# For ovarian cancer survival and platinum resistance prediction
# Optimized for MacBook Pro M4 (24GB RAM)
# Author: Claude AI Assistant
# Date: August 28, 2025

# Load required libraries
suppressPackageStartupMessages({
  library(tidyverse)
  library(randomForest)
  library(survival)
  library(survminer)
  library(caret)
  library(pheatmap)
  library(RColorBrewer)
  library(corrplot)
  library(ROCR)
  library(ggplot2)
  library(gridExtra)
  library(parallel)
})

cat("=== Foundation Model + Digital Twin Demonstration ===\n")
cat("Target: Ovarian Cancer Survival & Platinum Resistance Prediction\n")
cat("Platform: MacBook Pro M4 (24GB RAM optimized)\n\n")

# Set parameters for memory efficiency
set.seed(42)
options(mc.cores = min(8, parallel::detectCores())) # Limit cores for M4 chip

#' =============================================================================
#' STEP 1: SIMULATED FOUNDATION MODEL DATA GENERATION
#' =============================================================================

cat("Step 1: Generating simulated multi-modal ovarian cancer data...\n")

# Simulate patient cohort (manageable size for demo)
n_patients <- 200  # Reduced from 400 for demo efficiency
n_genes <- 500     # Reduced gene set (top cancer-related genes)
n_cnv_arms <- 38   # Chromosome arms

# Generate patient metadata
generate_patient_metadata <- function(n) {
  data.frame(
    patient_id = paste0("OV", sprintf("%03d", 1:n)),
    age = round(rnorm(n, 65, 12)),
    stage = sample(c("I", "II", "III", "IV"), n, replace = TRUE, 
                   prob = c(0.1, 0.1, 0.6, 0.2)),
    grade = sample(c("Low", "High"), n, replace = TRUE, prob = c(0.2, 0.8)),
    subtype = sample(c("HGSOC", "CCOC", "Other"), n, replace = TRUE, 
                     prob = c(0.6, 0.25, 0.15)),
    brca_status = sample(c("Wild-type", "BRCA1", "BRCA2"), n, replace = TRUE,
                         prob = c(0.75, 0.15, 0.1)),
    ca125_baseline = round(rlnorm(n, 6, 1.5)),
    stringsAsFactors = FALSE
  )
}

# Generate RNA expression data (log2 TPM)
generate_rna_expression <- function(n_patients, n_genes) {
  # Cancer-related gene symbols (simulated)
  gene_names <- paste0("GENE_", sprintf("%03d", 1:n_genes))
  
  # Base expression with subtype differences
  base_expr <- matrix(rnorm(n_patients * n_genes, 5, 2), 
                      nrow = n_genes, ncol = n_patients)
  
  # Add subtype-specific patterns
  hgsoc_idx <- which(metadata$subtype == "HGSOC")
  ccoc_idx <- which(metadata$subtype == "CCOC")
  
  # HGSOC signature (higher TP53, BRCA pathway genes)
  base_expr[1:50, hgsoc_idx] <- base_expr[1:50, hgsoc_idx] + rnorm(50 * length(hgsoc_idx), 2, 0.5)
  
  # CCOC signature (PIK3CA, mTOR pathway)
  base_expr[51:100, ccoc_idx] <- base_expr[51:100, ccoc_idx] + rnorm(50 * length(ccoc_idx), 2, 0.5)
  
  rownames(base_expr) <- gene_names
  colnames(base_expr) <- metadata$patient_id
  
  return(base_expr)
}

# Generate CNV data (log2 ratio)
generate_cnv_data <- function(n_patients, n_arms) {
  arm_names <- paste0("chr", rep(1:19, each = 2), c("p", "q"))
  
  cnv_data <- matrix(rnorm(n_patients * n_arms, 0, 0.3), 
                     nrow = n_arms, ncol = n_patients)
  
  # Add common CNV patterns in ovarian cancer
  # chr3q gain (common in HGSOC)
  hgsoc_idx <- which(metadata$subtype == "HGSOC")
  cnv_data[6, hgsoc_idx] <- cnv_data[6, hgsoc_idx] + rnorm(length(hgsoc_idx), 0.5, 0.2)
  
  # chr8q gain (MYC amplification)
  cnv_data[16, sample(1:n_patients, n_patients * 0.3)] <- 
    cnv_data[16, sample(1:n_patients, n_patients * 0.3)] + rnorm(n_patients * 0.3, 0.8, 0.2)
  
  rownames(cnv_data) <- arm_names
  colnames(cnv_data) <- metadata$patient_id
  
  return(cnv_data)
}

# Generate clinical outcomes
generate_outcomes <- function(metadata, rna_expr, cnv_data) {
  n <- nrow(metadata)
  
  # Survival time (months) - influenced by multiple factors
  base_survival <- 24  # Base 24 months
  
  # Age effect
  age_effect <- -0.3 * scale(metadata$age)[,1]
  
  # Stage effect
  stage_effect <- case_when(
    metadata$stage == "I" ~ 15,
    metadata$stage == "II" ~ 10,
    metadata$stage == "III" ~ 0,
    metadata$stage == "IV" ~ -10
  )
  
  # Subtype effect (CCOC worse prognosis)
  subtype_effect <- case_when(
    metadata$subtype == "CCOC" ~ -8,
    metadata$subtype == "HGSOC" ~ 0,
    TRUE ~ 2
  )
  
  # BRCA effect (better response)
  brca_effect <- case_when(
    metadata$brca_status == "BRCA1" ~ 8,
    metadata$brca_status == "BRCA2" ~ 6,
    TRUE ~ 0
  )
  
  # Gene expression effect (top survival genes)
  gene_effect <- colMeans(rna_expr[1:10, ]) * 2  # Top 10 survival genes
  
  # CNV effect (chromosome instability)
  cnv_instability <- apply(abs(cnv_data), 2, mean) * -10
  
  # Combine effects
  total_effect <- age_effect + stage_effect + subtype_effect + brca_effect + 
                  gene_effect + cnv_instability
  
  survival_months <- pmax(1, base_survival + total_effect + rnorm(n, 0, 5))
  
  # Event indicator (death)
  death_prob <- 1 / (1 + exp(-(total_effect * -0.1)))
  death_event <- rbinom(n, 1, death_prob)
  
  # Platinum resistance (influenced by different factors)
  # BRCA status strongly influences platinum sensitivity
  resistance_logit <- -1 +  # Base resistance probability
    ifelse(metadata$brca_status != "Wild-type", -2, 0) +  # BRCA protective
    ifelse(metadata$subtype == "CCOC", 1.5, 0) +          # CCOC more resistant
    colMeans(rna_expr[51:60, ]) * 0.5 +                   # Resistance genes
    rnorm(n, 0, 0.5)
  
  platinum_resistant <- rbinom(n, 1, plogis(resistance_logit))
  
  return(data.frame(
    patient_id = metadata$patient_id,
    survival_months = round(survival_months, 1),
    death_event = death_event,
    platinum_resistant = platinum_resistant,
    resistance_score = plogis(resistance_logit)
  ))
}

# Generate all data
metadata <- generate_patient_metadata(n_patients)
rna_data <- generate_rna_expression(n_patients, n_genes)
cnv_data <- generate_cnv_data(n_patients, n_cnv_arms)
outcomes <- generate_outcomes(metadata, rna_data, cnv_data)

# Combine into comprehensive dataset
full_data <- metadata %>%
  left_join(outcomes, by = "patient_id")

cat("Generated data for", n_patients, "patients with", n_genes, "genes\n")
cat("Subtypes:", table(full_data$subtype), "\n")
cat("BRCA status:", table(full_data$brca_status), "\n\n")

#' =============================================================================
#' STEP 2: FOUNDATION MODEL ARCHITECTURE (SIMPLIFIED)
#' =============================================================================

cat("Step 2: Building simplified foundation model...\n")

# Create integrated feature matrix for foundation model
create_integrated_features <- function(metadata, rna_data, cnv_data) {
  # Clinical features (encoded)
  clinical_features <- model.matrix(~ age + stage + grade + subtype + brca_status + 
                                   log(ca125_baseline + 1), data = metadata)[,-1]
  
  # Top variable genes (memory efficient)
  rna_var <- apply(rna_data, 1, var)
  top_genes <- names(sort(rna_var, decreasing = TRUE)[1:100])  # Top 100 variable genes
  rna_features <- t(rna_data[top_genes, ])
  
  # CNV features (all arms)
  cnv_features <- t(cnv_data)
  
  # Combine all features
  integrated_matrix <- cbind(clinical_features, rna_features, cnv_features)
  rownames(integrated_matrix) <- metadata$patient_id
  
  return(list(
    features = integrated_matrix,
    clinical_cols = 1:ncol(clinical_features),
    rna_cols = (ncol(clinical_features) + 1):(ncol(clinical_features) + 100),
    cnv_cols = (ncol(clinical_features) + 101):ncol(integrated_matrix)
  ))
}

integrated_data <- create_integrated_features(metadata, rna_data, cnv_data)
feature_matrix <- integrated_data$features

cat("Created integrated feature matrix:", dim(feature_matrix), "\n")
cat("Features: Clinical (", length(integrated_data$clinical_cols), 
    "), RNA (", length(integrated_data$rna_cols), 
    "), CNV (", length(integrated_data$cnv_cols), ")\n\n")

#' =============================================================================
#' STEP 3: SURVIVAL PREDICTION MODEL
#' =============================================================================

cat("Step 3: Training survival prediction model...\n")

# Prepare survival data
surv_data <- data.frame(
  feature_matrix,
  survival_months = full_data$survival_months,
  death_event = full_data$death_event
) %>%
  na.omit()

# Split data
set.seed(42)
train_idx <- createDataPartition(surv_data$death_event, p = 0.7, list = FALSE)[,1]
train_surv <- surv_data[train_idx, ]
test_surv <- surv_data[-train_idx, ]

# Train Random Survival Forest (memory efficient alternative to deep learning)
cat("Training survival model using Random Forest...\n")
survival_rf <- randomForest(
  x = train_surv[, 1:(ncol(feature_matrix))],
  y = train_surv$survival_months,
  ntree = 100,  # Reduced trees for demo
  mtry = sqrt(ncol(feature_matrix)),
  importance = TRUE,
  nodesize = 5
)

# Predict on test set
surv_predictions <- predict(survival_rf, test_surv[, 1:(ncol(feature_matrix))])

# Calculate performance metrics
surv_mae <- mean(abs(surv_predictions - test_surv$survival_months))
surv_rmse <- sqrt(mean((surv_predictions - test_surv$survival_months)^2))
surv_cor <- cor(surv_predictions, test_surv$survival_months)

cat("Survival Prediction Performance:\n")
cat("  MAE:", round(surv_mae, 2), "months\n")
cat("  RMSE:", round(surv_rmse, 2), "months\n") 
cat("  Correlation:", round(surv_cor, 3), "\n\n")

#' =============================================================================
#' STEP 4: PLATINUM RESISTANCE PREDICTION MODEL
#' =============================================================================

cat("Step 4: Training platinum resistance prediction model...\n")

# Prepare resistance data
resist_data <- data.frame(
  feature_matrix,
  platinum_resistant = full_data$platinum_resistant
) %>%
  na.omit()

# Split data (same indices for consistency)
train_resist <- resist_data[train_idx, ]
test_resist <- resist_data[-train_idx, ]

# Train classification model
cat("Training resistance model using Random Forest...\n")
resistance_rf <- randomForest(
  x = train_resist[, 1:(ncol(feature_matrix))],
  y = as.factor(train_resist$platinum_resistant),
  ntree = 100,
  mtry = sqrt(ncol(feature_matrix)),
  importance = TRUE,
  nodesize = 3
)

# Predict on test set
resist_pred_prob <- predict(resistance_rf, test_resist[, 1:(ncol(feature_matrix))], type = "prob")[,2]
resist_pred_class <- predict(resistance_rf, test_resist[, 1:(ncol(feature_matrix))])

# Calculate performance metrics
resist_auc <- prediction(resist_pred_prob, test_resist$platinum_resistant) %>%
  performance("auc") %>%
  slot("y.values") %>%
  unlist()

resist_accuracy <- mean(as.numeric(resist_pred_class) - 1 == test_resist$platinum_resistant)

cat("Platinum Resistance Prediction Performance:\n")
cat("  AUC:", round(resist_auc, 3), "\n")
cat("  Accuracy:", round(resist_accuracy, 3), "\n\n")

#' =============================================================================
#' STEP 5: DIGITAL TWIN IMPLEMENTATION
#' =============================================================================

cat("Step 5: Creating Digital Twin system...\n")

# Digital Twin class
create_digital_twin <- function(patient_id, models, data) {
  patient_idx <- which(data$full_data$patient_id == patient_id)
  if(length(patient_idx) == 0) stop("Patient not found")
  
  # Extract patient data
  patient_features <- data$feature_matrix[patient_idx, , drop = FALSE]
  patient_info <- data$full_data[patient_idx, ]
  
  # Make predictions
  survival_pred <- predict(models$survival_rf, patient_features)
  resistance_prob <- predict(models$resistance_rf, patient_features, type = "prob")[,2]
  
  # Create digital twin object
  digital_twin <- list(
    patient_id = patient_id,
    clinical_info = patient_info,
    predictions = list(
      survival_months = as.numeric(survival_pred),
      platinum_resistance_prob = as.numeric(resistance_prob),
      risk_category = ifelse(survival_pred < 18, "High", 
                            ifelse(survival_pred < 30, "Medium", "Low"))
    ),
    feature_importance = list(
      survival = importance(models$survival_rf)[order(importance(models$survival_rf)[,1], decreasing = TRUE)[1:10], ],
      resistance = importance(models$resistance_rf)[order(importance(models$resistance_rf)[,2], decreasing = TRUE)[1:10], ]
    )
  )
  
  return(digital_twin)
}

# Create models list for digital twin
models <- list(
  survival_rf = survival_rf,
  resistance_rf = resistance_rf
)

data_package <- list(
  full_data = full_data,
  feature_matrix = feature_matrix
)

# Test digital twin with sample patients
sample_patients <- sample(full_data$patient_id, 3)
digital_twins <- list()

for(pid in sample_patients) {
  digital_twins[[pid]] <- create_digital_twin(pid, models, data_package)
}

cat("Created digital twins for", length(sample_patients), "sample patients\n\n")

#' =============================================================================
#' STEP 6: VISUALIZATION AND REPORTING
#' =============================================================================

cat("Step 6: Generating visualization and report...\n")

# Function to print digital twin report
print_digital_twin_report <- function(dt) {
  cat("\n=== DIGITAL TWIN REPORT ===\n")
  cat("Patient ID:", dt$patient_id, "\n")
  cat("Age:", dt$clinical_info$age, "| Stage:", dt$clinical_info$stage, 
      "| Subtype:", dt$clinical_info$subtype, "\n")
  cat("BRCA Status:", dt$clinical_info$brca_status, 
      "| CA-125:", dt$clinical_info$ca125_baseline, "\n")
  
  cat("\nPREDICTIONS:\n")
  cat("  Predicted Survival:", round(dt$predictions$survival_months, 1), "months\n")
  cat("  Risk Category:", dt$predictions$risk_category, "\n")
  cat("  Platinum Resistance Probability:", round(dt$predictions$platinum_resistance_prob, 3), "\n")
  cat("  Resistance Classification:", 
      ifelse(dt$predictions$platinum_resistance_prob > 0.5, "RESISTANT", "SENSITIVE"), "\n")
  
  cat("\nACTUAL OUTCOMES (for validation):\n")
  cat("  Actual Survival:", dt$clinical_info$survival_months, "months\n")
  cat("  Actual Resistance:", 
      ifelse(dt$clinical_info$platinum_resistant == 1, "RESISTANT", "SENSITIVE"), "\n")
  
  cat("\nTOP SURVIVAL-RELATED FEATURES:\n")
  survival_imp <- dt$feature_importance$survival[1:5, , drop = FALSE]
  for(i in 1:nrow(survival_imp)) {
    cat("  ", rownames(survival_imp)[i], ": ", round(survival_imp[i,1], 3), "\n")
  }
  
  cat("\nTOP RESISTANCE-RELATED FEATURES:\n") 
  resistance_imp <- dt$feature_importance$resistance[1:5, , drop = FALSE]
  for(i in 1:nrow(resistance_imp)) {
    cat("  ", rownames(resistance_imp)[i], ": ", round(resistance_imp[i,2], 3), "\n")
  }
  cat("=====================================\n")
}

# Generate reports for sample patients
for(pid in names(digital_twins)) {
  print_digital_twin_report(digital_twins[[pid]])
}

# Create summary plots
create_summary_plots <- function() {
  # Performance plot
  p1 <- data.frame(
    Predicted = surv_predictions,
    Actual = test_surv$survival_months,
    Type = "Survival (months)"
  ) %>%
    ggplot(aes(x = Actual, y = Predicted)) +
    geom_point(alpha = 0.6, color = "steelblue") +
    geom_abline(intercept = 0, slope = 1, color = "red", linetype = "dashed") +
    labs(title = "Survival Prediction Performance",
         x = "Actual Survival (months)",
         y = "Predicted Survival (months)") +
    theme_minimal() +
    annotate("text", x = min(test_surv$survival_months), y = max(surv_predictions),
             label = paste("R =", round(surv_cor, 3)), hjust = 0)
  
  # ROC curve for resistance
  roc_data <- prediction(resist_pred_prob, test_resist$platinum_resistant) %>%
    performance("tpr", "fpr")
  
  p2 <- data.frame(
    fpr = roc_data@x.values[[1]],
    tpr = roc_data@y.values[[1]]
  ) %>%
    ggplot(aes(x = fpr, y = tpr)) +
    geom_line(color = "steelblue", size = 1.2) +
    geom_abline(intercept = 0, slope = 1, color = "red", linetype = "dashed") +
    labs(title = "Platinum Resistance Prediction ROC",
         x = "False Positive Rate",
         y = "True Positive Rate") +
    theme_minimal() +
    annotate("text", x = 0.6, y = 0.2, 
             label = paste("AUC =", round(resist_auc, 3)))
  
  # Distribution plots
  p3 <- full_data %>%
    ggplot(aes(x = subtype, y = survival_months, fill = subtype)) +
    geom_boxplot() +
    labs(title = "Survival by Subtype", 
         x = "Subtype", y = "Survival (months)") +
    theme_minimal() +
    theme(legend.position = "none")
  
  p4 <- full_data %>%
    ggplot(aes(x = factor(platinum_resistant), fill = subtype)) +
    geom_bar(position = "dodge") +
    labs(title = "Platinum Resistance by Subtype",
         x = "Platinum Resistant", y = "Count") +
    theme_minimal()
  
  return(list(p1, p2, p3, p4))
}

plots <- create_summary_plots()

#' =============================================================================
#' FINAL SUMMARY
#' =============================================================================

cat("\n\n=== FOUNDATION MODEL + DIGITAL TWIN DEMONSTRATION COMPLETE ===\n")
cat("Successfully implemented toy demonstration with:\n")
cat("• Simulated multi-modal ovarian cancer data (", n_patients, " patients)\n")
cat("• Foundation model architecture with clinical, RNA, and CNV integration\n")
cat("• Survival prediction (MAE:", round(surv_mae, 1), "months, R =", round(surv_cor, 3), ")\n")
cat("• Platinum resistance prediction (AUC:", round(resist_auc, 3), ")\n")
cat("• Digital twin system for personalized patient modeling\n")
cat("• Memory-optimized for MacBook Pro M4 (24GB RAM)\n\n")

cat("Key Features Demonstrated:\n")
cat("1. Multi-modal data integration (clinical + genomics)\n")
cat("2. Machine learning model training and validation\n")
cat("3. Patient-specific digital twin creation\n")
cat("4. Personalized survival and treatment response prediction\n")
cat("5. Feature importance analysis for clinical interpretation\n\n")

cat("This framework can be extended with:\n")
cat("• Real QueenMaryRNA and QueenMaryDNA data\n")
cat("• Deep learning architectures (if GPU available)\n") 
cat("• Longitudinal modeling for disease progression\n")
cat("• Integration with clinical decision support systems\n")
cat("• Validation on external cohorts\n\n")

# Save results for presentation
save(
  metadata, rna_data, cnv_data, outcomes, full_data,
  feature_matrix, models, digital_twins, plots,
  file = "foundation_model_digital_twin_demo.RData"
)

cat("Results saved to: foundation_model_digital_twin_demo.RData\n")
cat("=== DEMONSTRATION COMPLETE ===\n")