# Dart SDK asosiy image
FROM dart:stable AS build

# Ishlash papkasini yaratish
WORKDIR /app

# Dependency'larni nusxalash va o'rnatish
COPY pubspec.* ./
RUN dart pub get

# Barcha kodni nusxalash
COPY . .

# Build qilish
RUN dart pub get --offline
RUN dart_frog build

# Production uchun kichikroq image
FROM dart:stable

WORKDIR /app

# Build qilingan faylni nusxalash
COPY --from=build /app/build /app/build
COPY --from=build /app/pubspec.* /app/

# Port ochish
EXPOSE 8080

# Serverni ishga tushirish
CMD ["./build/bin/dart_frog_server", "--port", "8080"]
