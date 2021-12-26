variable "allow_users_to_change_password" {
  description = "Whether to allow users to change their own password."
  type = string
}

variable "hard_expiry" {
  description = "Whether users are prevented from setting a new password after their password has expired (i.e. require administrator reset)."
  type = string
}

variable "max_password_age" {
  description = "The number of days that an user password is valid."
  type = string
}

variable "minimum_password_length" {
  description = "Minimum length to require for user passwords."
  type = string
}

variable "password_reuse_prevention" {
  description = "The number of previous passwords that users are prevented from reusing."
  type = string
}

variable "require_lowercase_characters" {
  description = "Whether to require lowercase characters for user passwords."
  type = string
}

variable "require_numbers" {
  description = "Whether to require numbers for user passwords."
  type = string
}

variable "require_symbols" {
  description = "Whether to require symbols for user passwords."
  type = string
}

variable "require_uppercase_characters" {
  description = "Whether to require uppercase characters for user passwords."
  type = string
}
