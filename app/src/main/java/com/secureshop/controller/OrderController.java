package com.secureshop.controller;

import com.secureshop.model.Order;
import com.secureshop.model.OrderItem;
import com.secureshop.service.OrderService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/orders")
public class OrderController {

    private final OrderService orderService;

    public OrderController(OrderService orderService) {
        this.orderService = orderService;
    }

    public record OrderRequest(@NotEmpty List<OrderItem> items) {}

    @PostMapping
    public ResponseEntity<Order> submitOrder(@Valid @RequestBody OrderRequest request) {
        Order order = orderService.placeOrder(request.items());
        return ResponseEntity.status(HttpStatus.CREATED).body(order);
    }

    @GetMapping("/{id}")
    public ResponseEntity<Order> getOrder(@PathVariable String id) {
        return orderService.findById(id)
                .map(ResponseEntity::ok)
                .orElseGet(() -> ResponseEntity.notFound().build());
    }

    @GetMapping
    public List<Order> listOrders() {
        return orderService.findAll();
    }
}
