package com.umair.devsecopsapp;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class HealthController {

    @GetMapping("/")
    public String home() {
        return "AI DevSecOps Project Running Successfully";
    }

    @GetMapping("/api/message")
    public String message() {
        return "Hello Umair, your Java Maven app is ready for DevSecOps pipeline";
    }
}