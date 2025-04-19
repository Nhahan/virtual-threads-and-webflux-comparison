package com.example.webfluxgateway

import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.runApplication

@SpringBootApplication
class WebfluxGatewayApplication

fun main(args: Array<String>) {
    // Uses WebFlux/Netty by default
    runApplication<WebfluxGatewayApplication>(*args)
} 