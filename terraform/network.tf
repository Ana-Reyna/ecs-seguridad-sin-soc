data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_security_group" "app" {
  name        = "${var.name_prefix}-app"
  description = "Demo: servicio expuesto a proposito"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP (expuesto a internet a proposito para el demo)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.ingress_cidr]
  }

  egress {
    description = "Salida a todo"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
