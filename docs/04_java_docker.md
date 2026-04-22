# Java in Docker: Best Practices

## Dockerfile Base per Java

### Versione Semplice (Non Ottimizzata)

```dockerfile
FROM eclipse-temurin:21
WORKDIR /app
COPY target/app.jar app.jar
EXPOSE 8080
CMD ["java", "-jar", "app.jar"]
```

### Versione Ottimizzata (Multi-Stage)

```dockerfile
# Stage 1: Build
FROM maven:3.9-eclipse-temurin-21 AS builder
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline
COPY src ./src
RUN mvn package -DskipTests

# Stage 2: Runtime
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY --from=builder /app/target/*.jar app.jar
RUN addgroup -S spring && adduser -S spring -G spring
USER spring:spring
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
```

---

## Best Practices Java + Docker

### 1. Usa JRE, non JDK in Production

```dockerfile
# ❌ BAD: Include compiler, tools (500 MB+)
FROM eclipse-temurin:21

# ✅ GOOD: Solo runtime (180 MB)
FROM eclipse-temurin:21-jre-alpine
```

### 2. Ottimizza JVM per Container

```dockerfile
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY target/app.jar app.jar
USER spring:spring
EXPOSE 8080

# JVM tuning per container
ENTRYPOINT ["java", \
  "-XX:+UseContainerSupport", \
  "-XX:MaxRAMPercentage=75.0", \
  "-XX:+UseG1GC", \
  "-Djava.security.egd=file:/dev/./urandom", \
  "-jar", "app.jar"]
```

### 3. Layered JARs (Spring Boot 2.3+)

```xml
<!-- pom.xml -->
<build>
  <plugins>
    <plugin>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-maven-plugin</artifactId>
      <configuration>
        <layers>
          <enabled>true</enabled>
        </layers>
      </configuration>
    </plugin>
  </plugins>
</build>
```

```dockerfile
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
ARG JAR_FILE=target/*.jar
COPY ${JAR_FILE} app.jar
RUN java -Djarmode=layertools -jar app.jar extract
RUN rm app.jar

# Layer dependencies (cambiano raramente)
COPY dependencies/ ./
COPY spring-boot-loader/ ./
COPY snapshot-dependencies/ ./
COPY application/ ./

USER spring:spring
ENTRYPOINT ["java", "org.springframework.boot.loader.JarLauncher"]
```

---

## Esempio Completo: Spring Boot REST API

### pom.xml

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 
         https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    
    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.2.0</version>
    </parent>
    
    <groupId>com.example</groupId>
    <artifactId>java-docker-app</artifactId>
    <version>1.0.0</version>
    <name>Java Docker App</name>
    
    <properties>
        <java.version>21</java.version>
    </properties>
    
    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-actuator</artifactId>
        </dependency>
    </dependencies>
    
    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
            </plugin>
        </plugins>
    </build>
</project>
```

### Application.java

```java
package com.example.app;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@SpringBootApplication
public class Application {
    public static void main(String[] args) {
        SpringApplication.run(Application.class, args);
    }
}

@RestController
@RequestMapping("/api")
class ApiController {
    
    @GetMapping("/")
    public Response root() {
        return new Response("Java API running in Docker", "1.0.0");
    }
    
    @GetMapping("/users")
    public List<User> getUsers() {
        return List.of(
            new User(1, "Alice"),
            new User(2, "Bob")
        );
    }
}

record Response(String message, String version) {}
record User(int id, String name) {}
```

### application.yml

```yaml
server:
  port: 8080
  shutdown: graceful

spring:
  application:
    name: java-docker-app

management:
  endpoints:
    web:
      exposure:
        include: health,info
  endpoint:
    health:
      show-details: always
```

### Dockerfile

```dockerfile
# Build stage
FROM maven:3.9-eclipse-temurin-21 AS builder
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline
COPY src ./src
RUN mvn package -DskipTests

# Runtime stage
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY --from=builder /app/target/*.jar app.jar

RUN addgroup -S spring && adduser -S spring -G spring
USER spring:spring

EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/actuator/health || exit 1

ENTRYPOINT ["java", \
  "-XX:+UseContainerSupport", \
  "-XX:MaxRAMPercentage=75.0", \
  "-jar", "app.jar"]
```

---

## Build e Run

```bash
# Build con Maven
mvn clean package

# Build Docker image
docker build -t java-api:1.0 .

# Run
docker run -d -p 8080:8080 --name java-api java-api:1.0

# Test
curl http://localhost:8080/api/
curl http://localhost:8080/api/users
curl http://localhost:8080/actuator/health

# Logs
docker logs -f java-api

# Stop
docker stop java-api
```

---

## Docker Compose

```yaml
version: '3.8'
services:
  java-app:
    build: ./java-app
    ports:
      - "8080:8080"
    environment:
      - SPRING_PROFILES_ACTIVE=docker
      - JAVA_OPTS=-Xmx512m -Xms256m
    healthcheck:
      test: ["CMD", "wget", "--spider", "http://localhost:8080/actuator/health"]
      interval: 30s
      timeout: 3s
      retries: 3
```

---

## Ottimizzazioni Avanzate

### GraalVM Native Image (Startup Istantaneo)

```dockerfile
FROM ghcr.io/graalvm/graalvm-ce:ol8-java17 AS builder
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN ./mvnw native:compile -Pnative

FROM oraclelinux:8-slim
COPY --from=builder /app/target/app ./app
EXPOSE 8080
ENTRYPOINT ["./app"]
```

**Risultato**: Startup < 100ms, immagine 50 MB

---

## 📚 Risorse

- [Spring Boot Docker Guide](https://spring.io/guides/topicals/spring-boot-docker)
- [Eclipse Temurin Images](https://hub.docker.com/_/eclipse-temurin)
- [JVM Container Support](https://www.eclipse.org/openj9/docs/xxusecontainersupport/)
