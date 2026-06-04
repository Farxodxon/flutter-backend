FROM dart:stable AS build

WORKDIR /app

RUN dart pub global activate dart_frog_cli
ENV PATH="$PATH:/root/.pub-cache/bin"

COPY pubspec.* ./
RUN dart pub get

COPY . .

RUN dart_frog build

FROM dart:stable

WORKDIR /app

COPY --from=build /app/build /app/build
COPY --from=build /app/pubspec.* /app/

EXPOSE 8080

# server.dart faylini dart orqali ishga tushiramiz
CMD dart build/bin/server.dart --port ${PORT:-8080}
