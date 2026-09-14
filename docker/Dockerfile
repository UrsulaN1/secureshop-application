FROM eclipse-temurin:21-jdk AS build
WORKDIR /workspace
COPY . .
RUN mvn package -DskipTests
FROM eclipse-temurin:21-jre
RUN useradd --system --uid 10001 appuser
WORKDIR /app
COPY --from=build /workspace/target/*.jar app.jar
USER 10001
EXPOSE 8080
ENTRYPOINT ["java","-jar","/app/app.jar"]
