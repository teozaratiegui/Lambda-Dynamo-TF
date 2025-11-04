variable "table_name" {
  type = string
}

variable "billing_mode" {
  type    = string
  default = "PAY_PER_REQUEST"
}

variable "pitr" {
  type    = bool
  default = true

}
variable "tags" {
  type    = map(string)
  default = {}
}