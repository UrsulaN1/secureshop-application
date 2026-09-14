# US-020: production Dockerfile
# US-021: hardened / non-root / minimal image

# ---- Build stage ----
FROM eclipse-temurin:17-jdk-jammy AS build
WORKDIR /build
COPY pom.xml .
COPY src ./src
# Resolve deps and build without needing a full mvn install (US-011)
RUN apt-get update && apt-get install -y --no-install-recommends maven \
    && mvn -q -B -f pom.xml clean package -DskipTests \
    && apt-get purge -y maven && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*

# ---- Runtime stage (minimal, non-root) ----
FROM eclipse-temurin:17-jre-jammy
LABEL org.opencontainers.image.source="https://github.com/secureshop-org/secureshop" \
      org.opencontainers.image.title="secureshop" \
      org.opencontainers.image.description="SecureShop e-commerce API"

# Non-root user (US-021, US-034)
RUN groupadd -r secureshop && useradd -r -g secureshop -u 1001 secureshop

WORKDIR /app
COPY --from=build /build/target/secureshop.jar /app/secureshop.jar

RUN chown -R secureshop:secureshop /app
USER 1001

EXPOSE 8080
ENV JAVA_OPTS=""

HEALTHCHECK --interval=30s --timeout=3s --start-period=20s \
  CMD wget -qO- http://localhost:8080/actuator/health || exit 1

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar /app/secureshop.jar"]
