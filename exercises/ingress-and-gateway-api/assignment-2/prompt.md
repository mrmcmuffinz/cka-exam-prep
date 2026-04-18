I need you to create a comprehensive Kubernetes homework assignment to help me practice **Advanced Ingress and TLS**.

CONTEXT:
- I'm studying for the CKA (Certified Kubernetes Administrator) exam
- I'm using a kind cluster with nerdctl (rootless containers, not Docker)
- I have completed ingress-and-gateway-api/assignment-1
- I want to build real-world skills, not just pass the exam

SCOPE (IMPORTANT):
This assignment covers Ingress annotations, rewrite-target, TLS termination, certificate management, and advanced routing patterns. Basic Ingress is assumed from assignment-1. Gateway API is covered in assignment-3.

**In scope for this assignment:**

*Ingress Annotations*
- Controller-specific annotations
- nginx.ingress.kubernetes.io/rewrite-target
- nginx.ingress.kubernetes.io/ssl-redirect
- nginx.ingress.kubernetes.io/proxy-body-size
- Other common nginx-ingress annotations
- Annotation documentation and discovery

*Rewrite-Target*
- URL path rewriting
- Capturing groups in paths
- Rewriting /app/api to /api on backend
- Use cases: versioning, legacy paths
- Testing rewrite behavior

*TLS Termination with Ingress*
- spec.tls: list of TLS configurations
- spec.tls[].hosts: hostnames for this TLS config
- spec.tls[].secretName: Secret containing cert and key
- TLS Secret structure: tls.crt, tls.key
- Creating TLS Secrets

*Certificate Management for Ingress*
- Creating self-signed certificates for testing
- TLS Secret creation from cert files
- kubectl create secret tls
- Certificate rotation considerations
- cert-manager (conceptual, for production)

*Multi-Host and Multi-Path Rules*
- Complex routing with multiple hosts and paths
- Different TLS certs per host
- Combining path and host routing
- Default backend with TLS

*Ingress Controller Customization*
- Controller ConfigMap settings
- Default SSL certificate
- Rate limiting annotations
- Proxy timeouts

**Out of scope (covered in other assignments, do not include):**

- Basic Ingress structure (exercises/ingress-and-gateway-api/assignment-1)
- Path types basics (exercises/ingress-and-gateway-api/assignment-1)
- Gateway API (exercises/ingress-and-gateway-api/assignment-3)
- Certificate creation with openssl (exercises/tls-and-certificates/assignment-1)
- Certificates API (exercises/tls-and-certificates/assignment-2)

ASSIGNMENT REQUIREMENTS:

1. **Tutorial File (Separate from Exercises)**
   - Create a standalone tutorial file: ingress-and-gateway-api-tutorial.md (section 2)
   - Explain nginx-ingress annotations
   - Demonstrate rewrite-target with examples
   - Walk through TLS termination setup
   - Show certificate and Secret creation
   - Demonstrate complex routing scenarios
   - Use tutorial-ingress namespace

2. **Homework Exercises File (15 Progressive Exercises)**
   - Create the exercises file: ingress-and-gateway-api-homework.md
   - 15 exercises across 5 difficulty levels (3 exercises per level)

   **Level 1 (Exercises 1.1-1.3): Annotations**
   - Add common annotations to Ingress
   - Configure ssl-redirect
   - Test annotation effects

   **Level 2 (Exercises 2.1-2.3): Rewrite and TLS**
   - Configure rewrite-target
   - Create TLS Secret and Ingress
   - Test HTTPS access

   **Level 3 (Exercises 3.1-3.3): Debugging Advanced Ingress**
   - Three debugging exercises
   - Exercise headings are bare (### Exercise 3.1)
   - Scenarios: rewrite not working, TLS Secret wrong format, annotation typo

   **Level 4 (Exercises 4.1-4.3): Complex Configurations**
   - Multiple TLS hosts
   - Combine rewrite with TLS
   - Configure default SSL certificate

   **Level 5 (Exercises 5.1-5.3): Production Patterns**
   - Exercise 5.1: Migrate HTTP to HTTPS with redirects
   - Exercise 5.2: Debug complex TLS/routing issue
   - Exercise 5.3: Design production Ingress architecture

3. **Answer Key File**
   - Create the answer key: ingress-and-gateway-api-homework-answers.md
   - Full solutions with explanations
   - Common mistakes section covering:
     - Wrong annotation namespace (nginx.ingress.kubernetes.io)
     - TLS Secret missing tls.crt or tls.key
     - Rewrite-target regex wrong
     - Certificate not matching hostname
     - ssl-redirect causing loops
   - Advanced Ingress cheat sheet

4. **README File for the Assignment**
   - Create: README.md
   - Overview of Advanced Ingress and TLS assignment
   - Prerequisites: ingress-and-gateway-api/assignment-1
   - Estimated time commitment: 4-6 hours
   - Cluster requirements: multi-node kind with nginx-ingress
   - Recommended workflow

ENVIRONMENT REQUIREMENTS:
- Multi-node kind cluster with nginx-ingress (from assignment-1)
- openssl for certificate generation
- kubectl client

RESOURCE GATE:
All CKA resources are in scope (generation order 27):
- Ingress
- Secrets (TLS type)
- Services, Deployments, Pods
- Namespaces

CONVENTIONS:
- No em dashes anywhere.
- Narrative paragraph flow in prose sections.
- Exercise namespaces follow `ex-<level>-<exercise>` pattern.
- Tutorial namespace is `tutorial-ingress`.
- Debugging exercise headings are bare.
- Container images use explicit version tags.
- Full file replacements when generating.

CROSS-REFERENCES:
- **Prerequisites:**
  - exercises/ingress-and-gateway-api/assignment-1: Ingress fundamentals

- **Follow-up assignments:**
  - exercises/ingress-and-gateway-api/assignment-3: Gateway API

COURSE MATERIAL REFERENCE:
- S9 (Lectures 231-237): Ingress controllers, resources, annotations, rewrite-target
