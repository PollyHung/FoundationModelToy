setwd("~/Desktop/FoundationModel/")

# ccoc_patients <- QueenMaryRNA::Metadata %>% 
#   dplyr::filter(subtype_disease == "Clear Cell Ovarian Cancer" & sample %in% colnames(QueenMaryRNA::QueenMaryRNA) & sample %in% colnames(QueenMaryDNA::broad_values_by_arm))
# ccoc_RNA <- QueenMaryRNA::QueenMaryRNA[, ccoc_patients$sample]
# ccoc_DNA <- QueenMaryDNA::broad_values_by_arm[, c("Chromosome Arm", ccoc_patients$sample)]
# 
# write.table(ccoc_patients, "ccoc_metadata.txt", sep = "\t", quote = F, col.names = T, row.names = F)
# write.table(ccoc_RNA, "ccoc_tpm.txt", sep = "\t", quote = F, col.names = T, row.names = T)
# write.table(ccoc_DNA, "ccoc_arm_aneuploidy.txt", sep = "\t", quote = F, col.names = T, row.names = F)
