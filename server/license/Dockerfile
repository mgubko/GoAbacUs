# Cloud Run image for the licence server. Build from the repository root:
#   docker build -f server/license/Dockerfile -t goabacus-license .
FROM dart:stable AS build
WORKDIR /src
COPY packages/tutor_tasks packages/tutor_tasks
COPY server/license server/license
WORKDIR /src/server/license
RUN dart pub get && dart compile exe bin/server.dart -o /server

FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /server /server
EXPOSE 8080
CMD ["/server"]
