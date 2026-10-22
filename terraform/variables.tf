variable "region" {
  description = "Región donde se despliega todo (GuardDuty, Security Hub e Inspector se activan por región)."
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefijo para nombrar los recursos."
  type        = string
  default     = "ecs-sin-soc"
}

variable "alert_email" {
  description = "Correo que recibe las alertas (SNS) y el aviso del presupuesto. Puedes usar un alias con +, ej. nombre+gd-demo@dominio.com"
  type        = string
}

variable "service_desired_count" {
  description = "Tasks del servicio. Déjalo en 0 en el primer apply (aún no hay imagen en ECR) y ponlo en 1 después de subirla."
  type        = number
  default     = 0
}

variable "ingress_cidr" {
  description = "CIDR con acceso HTTP al servicio. 0.0.0.0/0 expone el servicio a internet (necesario para que Security Hub marque exposición). Si no lo necesitas, pon tu IP/32."
  type        = string
  default     = "0.0.0.0/0"
}

variable "task_role_policy_arn" {
  description = "Política administrada que se le da al rol de la task a propósito (permisos de más para el demo). SOLO PARA CUENTAS DE PRUEBA."
  type        = string
  default     = "arn:aws:iam::aws:policy/PowerUserAccess"
}

variable "enable_security_hub" {
  description = "Activa Security Hub (CSPM) con aws_securityhub_account. Los exposure findings del Security Hub nuevo se activan desde la consola; ver README."
  type        = bool
  default     = true
}

variable "budget_usd" {
  description = "Presupuesto mensual (USD) para la alarma de costos."
  type        = number
  default     = 20
}
