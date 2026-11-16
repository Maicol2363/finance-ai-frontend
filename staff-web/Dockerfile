FROM node:22.22.2-alpine@sha256:8ea2348b068a9544dae7317b4f3aafcdc032df1647bb7d768a05a5cad1a7683f AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM nginx:stable-alpine@sha256:901e593c95dc85f5a729f5765516321366ef4ac401821431d408897e95287d0a
COPY --from=build /app/dist/ /srv/staff-web/
COPY deploy/nginx.conf.template /etc/nginx/staff-web.conf.template
COPY deploy/start-nginx.sh /usr/local/bin/start-staff-web
RUN chmod 755 /usr/local/bin/start-staff-web
USER 101:101
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/start-staff-web"]
