variable "environment" {
  default     = "dev"
  description = "Deployment environment (e.g., dev, staging, prod)"
}

# ===================================
# Database Configuration
# ===================================
variable "db_name" {
  type        = string
  default     = "pantry_pilot"
  description = "Name of the default database"
}

variable "db_master_username" {
  type        = string
  default     = "pantry_user"
  description = "Master username for the database"
  sensitive   = true
}

variable "db_engine_version" {
  type        = string
  default     = "16.13"
  description = "Aurora PostgreSQL engine version"
}

variable "db_instance_class" {
  type        = string
  default     = "db.serverless"
  description = "Instance class for Aurora cluster instances"
}

variable "db_serverlessv2_scaling_min_capacity" {
  type        = number
  default     = 0
  description = "Minimum capacity for Aurora Serverless v2"
}

variable "db_serverlessv2_scaling_max_capacity" {
  type        = number
  default     = 1
  description = "Maximum capacity for Aurora Serverless v2"
}

variable "db_serverlessv2_auto_pause_seconds" {
  type        = number
  default     = 300
  description = "Number of seconds until Aurora Serverless v2 auto-pauses"
}

variable "db_publicly_accessible" {
  type        = bool
  default     = true
  description = "Enable public accessibility for the database"
}

variable "db_backup_retention_period" {
  type        = number
  default     = 1
  description = "Number of days to retain automated backups"
}

variable "db_skip_final_snapshot" {
  type        = bool
  default     = true
  description = "Skip creating a final snapshot when the cluster is destroyed"
}

# ===================================
# OpenCode AI Configuration
# ===================================
variable "opencode_base_url" {
  type        = string
  default     = "https://opencode.ai/zen/go/v1"
  description = "OpenCode AI base URL (OpenAI-compatible endpoint)"
}

variable "opencode_model" {
  type        = string
  default     = "deepseek-v4-flash"
  description = "OpenCode AI model identifier"
}

variable "opencode_reasoning_effort" {
  type        = string
  default     = ""
  description = "Optional: model reasoning effort (low/medium/high)"
}