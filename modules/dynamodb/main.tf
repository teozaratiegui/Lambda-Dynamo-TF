resource "aws_dynamodb_table" "this" {
  name         = var.table_name
  billing_mode = var.billing_mode


  hash_key = "id"

  # Solo se deben definir los atributos que son clave de partición o de ordenamiento
  attribute {
    name = "id"
    type = "N" # id numérico
  }

  # Indica que AWS mantiene un backup por 35 días para recuperarlo en caso de ser necesario
  point_in_time_recovery {
    enabled = var.pitr
  }

  # Combinamos las tags que están en variables con una tag "Name" para identificar al recurso
  tags = merge(var.tags, {
    "Name" = var.table_name
  })
}


# Seed the counter item: { id: 0, counter: 0 }
# Note: keeps id=0 reserved for metadata. All user rows start from 1.
resource "aws_dynamodb_table_item" "counter_seed" {
  table_name = aws_dynamodb_table.this.name
  hash_key   = aws_dynamodb_table.this.hash_key


  item = jsonencode({
    id      = { "N" : "0" }
    counter = { "N" : "0" }
  })

}