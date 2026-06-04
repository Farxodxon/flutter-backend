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

RUN dart pub global activate dart_frog_cli
ENV PATH="$PATH:/root/.pub-cache/bin"

COPY --from=build /app/build /app/build
COPY --from=build /app/pubspec.* /app/

EXPOSE 8080

# Build papkasidagi barcha fayllarni ko'ramiz va to'g'ri faylni ishga tushiramiz
CMD sh -c "ls -la build/bin/ && ./build/bin/dart_frog_server --port \${PORT:-8080}"
