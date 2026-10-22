# Detecta, prioriza, responde: seguridad en ECS sin un SOC

Demo de la charla. Despliega en **tu cuenta de pruebas** un servicio ECS en Fargate que se porta mal a propósito
(imagen vieja, expuesto a internet, rol con permisos de más) y lo vigila con:

- **Amazon GuardDuty** con Runtime Monitoring para ECS Fargate (y Extended Threat Detection, que viene activo por defecto).
- **Amazon Inspector** para escanear la imagen en ECR.
- **AWS Security Hub** para priorizar.
- **EventBridge + SNS** para avisarte por correo.

> ## ⚠️ Solo para cuentas de pruebas
> El servicio `contenedor-confiado` es **vulnerable a propósito**: imagen con CVEs conocidos, abierto a internet y con un
> rol de tarea con permisos de más ("le di permisos porque tenía buena cara"). **No lo despliegues en una cuenta con
> cosas reales, no lo dejes días prendido y haz `terraform destroy` al terminar.**

## Costos

GuardDuty tiene prueba gratuita de 30 días en cuentas nuevas, pero Fargate, Runtime Monitoring, Inspector y Security Hub
pueden generar cargos. **Revisa los precios vigentes de cada servicio antes de desplegar.** El módulo crea una alarma de
presupuesto (`budget_usd`, 20 USD por defecto) que te avisa al correo que configures. Para abaratar el demo no se usa NAT Gateway.

## Requisitos

- Terraform >= 1.5 y AWS CLI v2 con credenciales de la cuenta de pruebas.
- Docker (para subir la imagen vieja a ECR).
- [Session Manager plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html) (solo para `ECS Exec` durante el ensayo).
- Una VPC por defecto en la región elegida.
- Una cuenta donde **no** esté ya habilitado GuardDuty en esa región (si ya lo está, ver *Problemas comunes*).

## Estructura

```
terraform/          módulo completo (GuardDuty, Inspector, Security Hub, ECR, ECS, SNS/EventBridge, presupuesto)
scripts/            push-image.sh: sube la imagen vulnerable a ECR
imagen-vulnerable/  Dockerfile opcional: PHP viejo + librerías con CVEs conocidos (más hallazgos en Inspector)
```

## Despliegue (orden importante)

**1. Configura tus variables**

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# edita terraform.tfvars: region y alert_email
```

Si Security Hub **ya estaba activo** en tu cuenta (Terraform fallaría con un error 409), agrega `enable_security_hub = false`
en `terraform.tfvars`. Así no se crea ni se destruye desde aquí.

Para el correo puedes usar un alias con `+` (por ejemplo `tu-correo+gd-demo@dominio.com`): llega a tu bandeja pero no
mezcla las alertas del demo con tu correo normal. Si no te llega la confirmación de SNS, revisa spam.

**2. Primer apply: todo menos las tasks**

```bash
terraform init
terraform apply          # service_desired_count = 0 por defecto
```

Revisa tu correo y **confirma la suscripción de SNS** (el mensaje de `no-reply@sns.amazonaws.com`; la página debe decir
"Subscription confirmed!"). Sin esto no llegan las alertas. Puedes comprobarlo con:
`aws sns list-subscriptions-by-topic --topic-arn "$(terraform output -raw sns_topic_arn)"` (no debe decir `PendingConfirmation`).

**3. Sube la imagen vulnerable**

```bash
../scripts/push-image.sh                      # por defecto nginx:1.19.0
../scripts/push-image.sh imagen-vulnerable    # construye la imagen de imagen-vulnerable/ (más hallazgos)
```

Inspector la escanea al subirla. Revisa los hallazgos de CVEs en la consola de Inspector. Con `nginx:1.19.0` salen pocos
(sobre todo "Platform End Of Life"); con `imagen-vulnerable` salen decenas, incluyendo críticos.

**4. Segundo apply: arranca el servicio**

```bash
terraform apply -var="service_desired_count=1"
```

GuardDuty tiene que estar con Runtime Monitoring **antes** de que nazcan las tasks, porque el agente (sidecar) solo se agrega a
tasks nuevas. Si ya tenías el servicio corriendo antes de activarlo, fuerza un nuevo despliegue:
`aws ecs update-service --cluster <cluster> --service contenedor-confiado --force-new-deployment`.

**5. Verifica la cobertura**

```bash
aws guardduty list-coverage --detector-id "$(terraform output -raw guardduty_detector_id)" --region "$(terraform output -raw region)"
```

En la consola de ECS, la task debe mostrar un contenedor adicional del agente de GuardDuty. Si el sidecar no arranca, la task
corre igual pero sin cobertura.

## Ensayo / demo

**Attack sequence (vía confiable: finding de muestra)**

```bash
aws guardduty create-sample-findings \
  --detector-id "$(terraform output -raw guardduty_detector_id)" \
  --region "$(terraform output -raw region)" \
  --finding-types 'AttackSequence:ECS/CompromisedCluster'
```

Aparece con el prefijo **[SAMPLE]**. Sirve para ver la línea de tiempo de señales y para probar la regla de EventBridge
(debería llegarte un correo). Los datos son de muestra: dilo así en la charla.

**Señal real dentro del contenedor**

```bash
CLUSTER="$(terraform output -raw cluster_name)"
SERVICE="$(terraform output -raw service_name)"
TASK="$(aws ecs list-tasks --cluster "$CLUSTER" --service-name "$SERVICE" --query 'taskArns[0]' --output text)"

aws ecs execute-command --cluster "$CLUSTER" --task "$TASK" \
  --container contenedor-confiado --interactive --command "/bin/sh"

# dentro del contenedor, lookups a dominios de prueba (inofensivos):
getent hosts guarddutyc2activityb.com
```

En una prueba real (octubre de 2026), ese `getent` generó un finding `Backdoor:Runtime/C&CActivity.B!DNS` de severidad 8 que
nombra el proceso (`getent`) y el contenedor, y la regla de EventBridge mandó el correo. **Tarda minutos** y no está garantizado
en todas las cuentas: pruébalo antes y ten siempre el sample finding como respaldo. Para entrar con ECS Exec necesitas el
Session Manager plugin.

**Security Hub**

Los *exposure findings* pertenecen al Security Hub nuevo y se activan desde la consola (no verificado si tu versión del provider ya
los soporta en Terraform). Una vez activos, busca el servicio ECS: debería mostrar vulnerabilidad + exposición a internet + rol con
permisos de más, con su ruta de ataque. Puede tardar horas en aparecer y **esta parte no se verificó** en la prueba.

## Limpieza

```bash
cd terraform
terraform destroy
```

Esto elimina todo lo creado, incluyendo el detector de GuardDuty y la habilitación de Inspector. Después revisa en la consola que
GuardDuty, Inspector y Security Hub queden desactivados y que no queden recursos huérfanos.

## Problemas comunes

- **"detector already exists"**: GuardDuty ya estaba habilitado en la región. Importa el detector existente
  (`terraform import aws_guardduty_detector.this <detector-id>`) o usa otra región/cuenta.
- **La task no arranca**: confirma que existe la imagen `contenedor-confiado:vulnerable` en ECR y que subiste la imagen como `linux/amd64`.
- **Sin cobertura de Runtime Monitoring**: revisa que el servicio se creó *después* de activar la feature, y que el security group permita salida a ECR y S3.
- **"Account is already subscribed to Security Hub" (409)**: pon `enable_security_hub = false` en `terraform.tfvars` y repite el apply.
- **La suscripción de SNS sigue en `PendingConfirmation`**: abre el correo de confirmación (revisa spam) o vuelve a suscribir
  el mismo correo con `aws sns subscribe` para que lo reenvíe.
- **`docker-credential-desktop` no encontrado** al subir la imagen (Docker sin Docker Desktop, por ejemplo con Colima): quita la
  línea `credsStore` de `~/.docker/config.json`.
- **`403` al subir capas a ECR**: casi siempre son credenciales de AWS distintas o vencidas; revisa `aws sts get-caller-identity`
  y el perfil (`AWS_PROFILE`).
- **Suppression rules**: GuardDuty no considera findings archivados (incluidos los suprimidos) para formar attack sequences.

## Estado

Probado de punta a punta en una cuenta de pruebas (octubre de 2026): despliegue con Terraform, task con el sidecar de
GuardDuty, hallazgos de Inspector, sample finding de attack sequence con correo, y un finding real de Runtime Monitoring.
**No verificado:** los exposure findings de Security Hub, y los tiempos exactos de cada finding. Si algo falla, abre un issue.

## Licencia

[MIT](LICENSE). Úsalo, cámbialo y compártelo; sin garantía. Es material de demostración con recursos vulnerables a propósito: úsalo bajo tu propia responsabilidad y solo en cuentas de pruebas.
