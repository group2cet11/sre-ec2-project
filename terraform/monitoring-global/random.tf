# This generates a unique random ID for all resource names
resource "random_id" "suffix" {
  byte_length = 4
}
