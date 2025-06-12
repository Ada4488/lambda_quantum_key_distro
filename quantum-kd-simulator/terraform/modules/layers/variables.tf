
variable "layer_name_prefix" {
  description = "Prefix for the Lambda layer names."
  type        = string
  default     = "qkd-sim"
}

variable "crypto_layer_source_path" {
  description = "Path to the source directory for the crypto layer (e.g., src/layers/crypto-layer/python)." # Note: path needs to be to the folder with packages, not just requirements.txt
  type        = string
}

variable "utilities_layer_source_path" {
  description = "Path to the source directory for the utilities layer (e.g., src/layers/utilities-layer/python)." # Note: path needs to be to the folder with packages, not just requirements.txt
  type        = string
}

variable "compatible_runtimes" {
  description = "A list of Runtimes this layer is compatible with."
  type        = list(string)
  default     = ["python3.9", "python3.10", "python3.11", "python3.12"]
}

variable "tags" {
  description = "A map of tags to assign to the resources."
  type        = map(string)
  default     = {}
}
