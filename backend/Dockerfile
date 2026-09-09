FROM dart:stable

WORKDIR /app

COPY pubspec.yaml pubspec.lock* ./
RUN dart pub get

COPY . .

RUN dart pub get
RUN dart compile exe bin/server.dart -o server

CMD ["./server"]