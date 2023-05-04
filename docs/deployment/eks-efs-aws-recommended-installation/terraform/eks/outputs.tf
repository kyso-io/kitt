output "private_subnets" {
  value       = module.vpc.private_subnets
  description = "Private subnet ids"
}
