package com.secureshop.service;

import com.secureshop.model.Order;
import com.secureshop.model.OrderItem;
import com.secureshop.model.Product;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.util.List;
import java.util.NoSuchElementException;

import static org.junit.jupiter.api.Assertions.*;

class OrderServiceTest {

    private ProductService productService;
    private OrderService orderService;

    @BeforeEach
    void setUp() {
        productService = new ProductService();
        orderService = new OrderService(productService);
    }

    @Test
    void placeOrder_succeedsAndComputesTotal() {
        Product p = productService.save(new Product(null, "Item", "d", new BigDecimal("10.00"), 5));
        Order order = orderService.placeOrder(List.of(new OrderItem(p.getId(), 2)));
        assertEquals(new BigDecimal("20.00"), order.getTotal());
        assertEquals("SUBMITTED", order.getStatus());
    }

    @Test
    void placeOrder_throwsForUnknownProduct() {
        assertThrows(NoSuchElementException.class,
                () -> orderService.placeOrder(List.of(new OrderItem("bogus-id", 1))));
    }

    @Test
    void placeOrder_throwsForEmptyItems() {
        assertThrows(IllegalArgumentException.class, () -> orderService.placeOrder(List.of()));
    }

    @Test
    void getOrder_retrievesSubmittedOrder() {
        Product p = productService.save(new Product(null, "Item", "d", new BigDecimal("3.00"), 5));
        Order order = orderService.placeOrder(List.of(new OrderItem(p.getId(), 1)));
        assertTrue(orderService.findById(order.getId()).isPresent());
    }
}
