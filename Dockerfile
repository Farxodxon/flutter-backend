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

# Dart Frog CLI kerak
RUN dart pub global activate dart_frog_cli
ENV PATH="$PATH:/root/.pub-cache/bin"

# Build qilingan fayllarni nusxalash
COPY --from=build /app/build /app/build
COPY --from=build /app/pubspec.* /app/

# Dependency'larni production image'ga ham o'rnatish
RUN dart pub get

EXPOSE 8080

# server.dart faylini dart orqali ishga tushirish
CMD dart build/bin/server.dart --port ${PORT:-8080}
