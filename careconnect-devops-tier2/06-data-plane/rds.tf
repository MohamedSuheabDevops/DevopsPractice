# REAL AWS ONLY. Two databases like the retail store: MySQL (catalog) and PostgreSQL (orders).
resource "aws_db_subnet_group" "this" {
  count      = var.create_rds || var.create_elasticache ? 1 : 0
  name       = "${var.project}-db"
  subnet_ids = var.private_subnet_ids
}

resource "aws_security_group" "data" {
  count       = var.create_rds || var.create_elasticache ? 1 : 0
  name        = "${var.project}-data"
  description = "Allow data-plane access from the cluster only"
  vpc_id      = var.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "mysql" {
  count                        = var.create_rds ? length(var.allowed_security_group_ids) : 0
  security_group_id            = aws_security_group.data[0].id
  referenced_security_group_id = var.allowed_security_group_ids[count.index]
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
}

resource "aws_vpc_security_group_ingress_rule" "postgres" {
  count                        = var.create_rds ? length(var.allowed_security_group_ids) : 0
  security_group_id            = aws_security_group.data[0].id
  referenced_security_group_id = var.allowed_security_group_ids[count.index]
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

resource "aws_vpc_security_group_ingress_rule" "redis" {
  count                        = var.create_elasticache ? length(var.allowed_security_group_ids) : 0
  security_group_id            = aws_security_group.data[0].id
  referenced_security_group_id = var.allowed_security_group_ids[count.index]
  ip_protocol                  = "tcp"
  from_port                    = 6379
  to_port                      = 6379
}

resource "aws_db_instance" "catalog_mysql" {
  count                       = var.create_rds ? 1 : 0
  identifier                  = "${var.project}-catalog"
  engine                      = "mysql"
  engine_version              = "8.0"
  instance_class              = "db.t4g.micro"
  allocated_storage           = 20
  db_name                     = "catalog"
  username                    = "catalog_admin"
  manage_master_user_password = true            # RDS creates and rotates the password in Secrets Manager
  db_subnet_group_name        = aws_db_subnet_group.this[0].name
  vpc_security_group_ids      = [aws_security_group.data[0].id]
  publicly_accessible         = false
  storage_encrypted           = true
  skip_final_snapshot         = true             # practice only!
  deletion_protection         = false            # practice only!
}

resource "aws_db_instance" "orders_postgres" {
  count                       = var.create_rds ? 1 : 0
  identifier                  = "${var.project}-orders"
  engine                      = "postgres"
  engine_version              = "16"
  instance_class              = "db.t4g.micro"
  allocated_storage           = 20
  db_name                     = "orders"
  username                    = "orders_admin"
  manage_master_user_password = true
  db_subnet_group_name        = aws_db_subnet_group.this[0].name
  vpc_security_group_ids      = [aws_security_group.data[0].id]
  publicly_accessible         = false
  storage_encrypted           = true
  skip_final_snapshot         = true
  deletion_protection         = false
}
