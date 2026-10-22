FROM composer:2.2
WORKDIR /app
RUN composer require --no-interaction --ignore-platform-reqs \
      phpmailer/phpmailer:5.2.16 \
      guzzlehttp/guzzle:6.3.0 \
      twig/twig:1.35.0 \
      symfony/http-kernel:4.4.0
ENTRYPOINT []
CMD ["sleep", "infinity"]
