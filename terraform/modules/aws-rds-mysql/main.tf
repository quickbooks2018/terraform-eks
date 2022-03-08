#########
# Labels
########
module "label" {
  source     = "../terraform-label"
  namespace  = var.namespace
  stage      = var.stage
  delimiter  = var.delimiter
  attributes = var.attributes
  tags       = var.tags
  enabled    = var.enabled
}




resource "aws_db_instance" "db" {
  name                                                     = var.db-name
  identifier                                               = var.rds-identifier
  final_snapshot_identifier                                = var.final-snapshot-identifier
  allocated_storage                                        = var.rds-allocated-storage
  storage_type                                             = var.storage-type
  engine                                                   = var.rds-engine
  engine_version                                           = var.engine-version
  instance_class                                           = var.db-instance-class
  backup_retention_period                                  = var.backup-retension-period
  backup_window                                            = var.backup-window
  publicly_accessible                                      = var.publicly-accessible
  username                                                 = var.rds-username
  password                                                 = var.rds-password
  vpc_security_group_ids                                   = var.vpc-security-group-ids
  db_subnet_group_name                                     = var.db-subnet-group-name
  skip_final_snapshot                                      = var.skip-final-snapshot
  multi_az                                                 = var.multi-az
  storage_encrypted                                        = var.storage-encrypted
  deletion_protection                                      = var.deletion-protection
}

