FROM docker.io/floryn90/hugo:0.141.0-alpine-ci AS builder

USER root

WORKDIR /src
COPY . .

RUN hugo --minify -d /public

FROM docker.io/library/nginx:alpine

RUN rm -rf /usr/share/nginx/html/*

# copy from /public instead of /src/public
COPY --from=builder /public /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

