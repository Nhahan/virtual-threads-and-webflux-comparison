package com.example.backendservice.controller

import org.slf4j.LoggerFactory
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.RestController
import java.util.concurrent.TimeUnit

@RestController
class DelayController {

    private val logger = LoggerFactory.getLogger(javaClass)

    @GetMapping("/delay/{seconds}")
    fun delay(@PathVariable seconds: Long): Map<String, Any> {
        val start = System.nanoTime()
        logger.info("Received request to delay for {} seconds on thread {}", seconds, Thread.currentThread())
        try {
            Thread.sleep(TimeUnit.SECONDS.toMillis(seconds))
        } catch (e: InterruptedException) {
            Thread.currentThread().interrupt()
            logger.error("Delay interrupted", e)
            throw RuntimeException("Delay interrupted", e)
        }
        val duration = TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - start)
        logger.info("Finished delay of {} seconds (took {} ms) on thread {}", seconds, duration, Thread.currentThread())
        return mapOf(
            "message" to "Delayed for $seconds seconds",
            "actual_delay_ms" to duration,
            "thread" to Thread.currentThread().toString()
        )
    }
    
    @GetMapping("/delay/ms/{milliseconds}")
    fun delayMilliseconds(@PathVariable milliseconds: Long): Map<String, Any> {
        val start = System.nanoTime()
        logger.info("Received request to delay for {} milliseconds on thread {}", milliseconds, Thread.currentThread())
        try {
            Thread.sleep(milliseconds)
        } catch (e: InterruptedException) {
            Thread.currentThread().interrupt()
            logger.error("Delay interrupted", e)
            throw RuntimeException("Delay interrupted", e)
        }
        val duration = TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - start)
        logger.info("Finished delay of {} milliseconds (took {} ms) on thread {}", milliseconds, duration, Thread.currentThread())
        return mapOf(
            "message" to "Delayed for $milliseconds milliseconds",
            "actual_delay_ms" to duration,
            "ms" to milliseconds,
            "thread" to Thread.currentThread().toString()
        )
    }
} 