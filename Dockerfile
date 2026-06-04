# Dart SDK asosiy image
FROM dart:stable AS build

# Ishlash papkasini yaratish
WORKDIR /app

# Dart Frog CLI o'rnatish
RUN dart pub global activate dart_frog_cli
ENV PATH="$PATH:/root/.pub-cache/bin"

# Dependency'larni nusxalash va o'rnatish
COPY pubspec.* ./
RUN dart pub get

# Barcha kodni nusxalash
COPY . .

# Dart Frog build
RUN dart_frog build

# Production uchun image
FROM dart:stable

WORKDIR /app

# Dart Frog CLI productionda ham kerak (ishga tushirish uchun)
RUN dart pub global activate dart_frog_cli
ENV PATH="$PATH:/root/.pub-cache/bin"

# Build qilingan faylni nusxalash
COPY --from=build /app/build /app/build
COPY --from=build /app/pubspec.* /app/

# Port ochish
EXPOSE 8080

# Serverni ishga tushirish
CMD ["./build/bin/dart_frog_server", "--port", "8080"]
