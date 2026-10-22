resource "aws_sns_topic" "alerts" {
  name = "${var.name_prefix}-alertas"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_event_rule" "guardduty_high" {
  name        = "${var.name_prefix}-guardduty-severidad-alta"
  description = "Findings de GuardDuty con severidad >= 7 (alta y critica)"

  event_pattern = jsonencode({
    source        = ["aws.guardduty"]
    "detail-type" = ["GuardDuty Finding"]
    detail = {
      severity = [{ numeric = [">=", 7] }]
    }
  })
}

resource "aws_cloudwatch_event_target" "to_sns" {
  rule = aws_cloudwatch_event_rule.guardduty_high.name
  arn  = aws_sns_topic.alerts.arn

  input_transformer {
    input_paths = {
      severity = "$.detail.severity"
      type     = "$.detail.type"
      title    = "$.detail.title"
      account  = "$.account"
      region   = "$.region"
      id       = "$.detail.id"
    }
    input_template = "\"[GuardDuty] severidad <severity> | <type>\\n<title>\\nCuenta <account> / <region>\\nFinding id: <id>\""
  }
}

data "aws_iam_policy_document" "sns_from_events" {
  statement {
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.alerts.arn]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

resource "aws_sns_topic_policy" "alerts" {
  arn    = aws_sns_topic.alerts.arn
  policy = data.aws_iam_policy_document.sns_from_events.json
}
