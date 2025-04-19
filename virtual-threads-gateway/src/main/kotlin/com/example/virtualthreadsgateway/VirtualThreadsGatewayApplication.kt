package com.example.virtualthreadsgateway

import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.runApplication

@SpringBootApplication
class VirtualThreadsGatewayApplication

fun main(args: Array<String>) {
    // Virtual threads are enabled via application.yml
    runApplication<VirtualThreadsGatewayApplication>(*args)
} 