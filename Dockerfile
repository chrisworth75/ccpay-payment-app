FROM eclipse-temurin:21-jre-alpine

WORKDIR /opt/app

COPY build/libs/payment-app.jar /opt/app/payment-app.jar

EXPOSE 8080

ENTRYPOINT ["java", "--add-opens", "java.base/java.lang=ALL-UNNAMED", "-jar", "payment-app.jar"]
