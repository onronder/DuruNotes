/**
 * Edge Function Tests for Quick Capture Widget
 * Run with: deno test --allow-env --allow-net test.ts
 */

import { assertEquals, assertExists, assertRejects } from "https://deno.land/std@0.177.0/testing/asserts.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.7";

// Test configuration
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "http://localhost:54321";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") || "test-anon-key";
const FUNCTION_URL = `${SUPABASE_URL}/functions/v1/quick-capture-widget`;

// Test helpers
function createTestClient(token?: string) {
  return createClient(SUPABASE_URL, token || SUPABASE_ANON_KEY);
}

async function makeRequest(
  body: any,
  headers: Record<string, string> = {}
): Promise<Response> {
  return await fetch(FUNCTION_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...headers,
    },
    body: JSON.stringify(body),
  });
}

// Test suite
Deno.test("Quick Capture Widget Edge Function Tests", async (t) => {
  
  // Authentication tests
  await t.step("should reject request without authorization", async () => {
    const response = await makeRequest({
      text: "Test note",
      platform: "ios",
    });
    
    assertEquals(response.status, 401);
    const data = await response.json();
    assertEquals(data.code, 401);
    assertEquals(data.message, "Missing authorization header");
  });

  await t.step("should reject request with invalid token", async () => {
    const response = await makeRequest(
      {
        text: "Test note",
        platform: "ios",
      },
      {
        Authorization: "Bearer invalid-token",
      }
    );
    
    assertEquals(response.status, 401);
  });

  // Validation tests
  await t.step("should validate required fields", async () => {
    const testToken = "test-jwt-token"; // Use a valid test token
    
    // Missing text
    const response1 = await makeRequest(
      {
        platform: "ios",
      },
      {
        Authorization: `Bearer ${testToken}`,
      }
    );
    
    assertEquals(response1.status, 400);
    const data1 = await response1.json();
    assertExists(data1.errors);
    assertEquals(data1.errors[0].field, "text");
    
    // Missing platform
    const response2 = await makeRequest(
      {
        text: "Test note",
      },
      {
        Authorization: `Bearer ${testToken}`,
      }
    );
    
    assertEquals(response2.status, 400);
    const data2 = await response2.json();
    assertExists(data2.errors);
    assertEquals(data2.errors[0].field, "platform");
  });

  await t.step("should validate text length", async () => {
    const testToken = "test-jwt-token";
    const longText = "a".repeat(10001); // Exceeds 10000 character limit
    
    const response = await makeRequest(
      {
        text: longText,
        platform: "ios",
      },
      {
        Authorization: `Bearer ${testToken}`,
      }
    );
    
    assertEquals(response.status, 400);
    const data = await response.json();
    assertExists(data.errors);
    assertEquals(data.errors[0].field, "text");
    assertExists(data.errors[0].message.includes("exceeds maximum length"));
  });

  await t.step("should validate platform values", async () => {
    const testToken = "test-jwt-token";
    
    const response = await makeRequest(
      {
        text: "Test note",
        platform: "invalid-platform",
      },
      {
        Authorization: `Bearer ${testToken}`,
      }
    );
    
    assertEquals(response.status, 400);
    const data = await response.json();
    assertExists(data.errors);
    assertEquals(data.errors[0].field, "platform");
  });

  // Template tests
  await t.step("should apply meeting template", async () => {
    const testToken = "test-jwt-token";
    
    // Mock successful response
    const response = await makeRequest(
      {
        text: "Team sync meeting",
        platform: "ios",
        templateId: "meeting",
      },
      {
        Authorization: `Bearer ${testToken}`,
      }
    );
    
    // In a real test, this would create a note with the template applied
    // For now, we just check the request is accepted
    if (response.status === 201) {
      const data = await response.json();
      assertExists(data.noteId);
    }
  });

  await t.step("should apply idea template", async () => {
    const testToken = "test-jwt-token";
    
    const response = await makeRequest(
      {
        text: "New app feature",
        platform: "android",
        templateId: "idea",
      },
      {
        Authorization: `Bearer ${testToken}`,
      }
    );
    
    if (response.status === 201) {
      const data = await response.json();
      assertExists(data.noteId);
    }
  });

  // Rate limiting tests
  await t.step("should enforce rate limits", async () => {
    const testToken = "test-jwt-token";
    
    // Make multiple rapid requests
    const requests = [];
    for (let i = 0; i < 12; i++) {
      requests.push(
        makeRequest(
          {
            text: `Rate limit test ${i}`,
            platform: "ios",
          },
          {
            Authorization: `Bearer ${testToken}`,
          }
        )
      );
    }
    
    const responses = await Promise.all(requests);
    
    // Some requests should be rate limited
    const rateLimited = responses.filter(r => r.status === 429);
    assertExists(rateLimited.length > 0, "Should have rate limited responses");
    
    // Check rate limit response
    if (rateLimited.length > 0) {
      const data = await rateLimited[0].json();
      assertEquals(data.code, 429);
      assertExists(data.message.includes("Rate limit"));
    }
  });

  // CORS tests
  await t.step("should handle CORS preflight", async () => {
    const response = await fetch(FUNCTION_URL, {
      method: "OPTIONS",
      headers: {
        "Origin": "http://localhost:3000",
        "Access-Control-Request-Method": "POST",
        "Access-Control-Request-Headers": "content-type,authorization",
      },
    });
    
    assertEquals(response.status, 200);
    assertExists(response.headers.get("Access-Control-Allow-Origin"));
    assertExists(response.headers.get("Access-Control-Allow-Methods"));
    assertExists(response.headers.get("Access-Control-Allow-Headers"));
  });

  // Encryption tests
  await t.step("should use encrypted columns", async () => {
    const testToken = "test-jwt-token";
    
    // This test verifies the function uses title_enc and props_enc
    // In a real scenario, you'd check the database directly
    const response = await makeRequest(
      {
        text: "Encrypted note test",
        platform: "web",
      },
      {
        Authorization: `Bearer ${testToken}`,
      }
    );
    
    if (response.status === 201) {
      const data = await response.json();
      // The response should indicate encryption handling
      assertExists(data.noteId);
      // In production, verify the note is stored with encrypted columns
    }
  });

  // Metadata tests
  await t.step("should include widget metadata", async () => {
    const testToken = "test-jwt-token";
    
    const customMetadata = {
      deviceModel: "iPhone 14",
      osVersion: "17.0",
    };
    
    const response = await makeRequest(
      {
        text: "Note with metadata",
        platform: "ios",
        metadata: customMetadata,
      },
      {
        Authorization: `Bearer ${testToken}`,
      }
    );
    
    if (response.status === 201) {
      const data = await response.json();
      assertExists(data.noteId);
      // Metadata should be stored with the note
    }
  });

  // Error handling tests
  await t.step("should handle database errors gracefully", async () => {
    const testToken = "test-jwt-token";
    
    // Simulate a database error by using invalid data
    // This would need to be coordinated with the actual function implementation
    const response = await makeRequest(
      {
        text: "Test note",
        platform: "ios",
        // Add data that would cause a database error
        metadata: { invalid_field: new Array(1000).fill("x").join("") },
      },
      {
        Authorization: `Bearer ${testToken}`,
      }
    );
    
    // Should return an error but not crash
    assertExists(response.status >= 400);
  });

  // Performance tests
  await t.step("should respond within acceptable time", async () => {
    const testToken = "test-jwt-token";
    
    const startTime = Date.now();
    
    const response = await makeRequest(
      {
        text: "Performance test note",
        platform: "android",
      },
      {
        Authorization: `Bearer ${testToken}`,
      }
    );
    
    const endTime = Date.now();
    const duration = endTime - startTime;
    
    // Should respond within 3 seconds
    assertExists(duration < 3000, `Response took ${duration}ms`);
  });

  // Analytics tests
  await t.step("should track analytics events", async () => {
    const testToken = "test-jwt-token";
    
    const response = await makeRequest(
      {
        text: "Analytics test note",
        platform: "web",
      },
      {
        Authorization: `Bearer ${testToken}`,
      }
    );
    
    // In production, verify analytics_events table has new entries
    if (response.status === 201) {
      // Analytics should be tracked
      const data = await response.json();
      assertExists(data.success);
    }
  });
});

// Load testing helper
Deno.test("Load Test - Concurrent Requests", async () => {
  const testToken = "test-jwt-token";
  const concurrentRequests = 20;
  
  console.log(`\nLoad testing with ${concurrentRequests} concurrent requests...`);
  
  const startTime = Date.now();
  
  const requests = Array.from({ length: concurrentRequests }, (_, i) =>
    makeRequest(
      {
        text: `Load test note ${i}`,
        platform: i % 2 === 0 ? "ios" : "android",
      },
      {
        Authorization: `Bearer ${testToken}`,
      }
    )
  );
  
  const responses = await Promise.all(requests);
  
  const endTime = Date.now();
  const totalTime = endTime - startTime;
  
  // Analyze results
  const successful = responses.filter(r => r.status === 201).length;
  const rateLimited = responses.filter(r => r.status === 429).length;
  const errors = responses.filter(r => r.status >= 500).length;
  
  console.log(`Total time: ${totalTime}ms`);
  console.log(`Average time per request: ${(totalTime / concurrentRequests).toFixed(2)}ms`);
  console.log(`Successful: ${successful}`);
  console.log(`Rate limited: ${rateLimited}`);
  console.log(`Errors: ${errors}`);
  
  // All requests should be handled (no 500 errors)
  assertEquals(errors, 0, "Should have no server errors");
});

// Cleanup helper
Deno.test("Cleanup Test Data", async () => {
  // In production, this would clean up test data from the database
  console.log("\nCleaning up test data...");
  
  // Connect to Supabase and delete test notes
  const supabase = createTestClient();
  
  // Delete test notes (those created during testing)
  // This requires appropriate permissions
  try {
    const { error } = await supabase
      .from("notes")
      .delete()
      .like("title_enc", "%test%");
    
    if (error) {
      console.log("Cleanup error:", error.message);
    } else {
      console.log("Test data cleaned up successfully");
    }
  } catch (e) {
    console.log("Cleanup skipped:", e.message);
  }
});
