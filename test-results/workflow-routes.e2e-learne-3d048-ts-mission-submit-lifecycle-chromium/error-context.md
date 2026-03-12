# Page snapshot

```yaml
- generic [active] [ref=e1]:
  - generic [ref=e3]:
    - group "Theme" [ref=e5]:
      - 'button "Theme: System" [pressed] [ref=e6]': System
      - 'button "Theme: Light" [ref=e7]': Light
      - 'button "Theme: Dark" [ref=e8]': Dark
    - generic [ref=e9]:
      - generic [ref=e10]:
        - heading "Welcome back" [level=2] [ref=e11]
        - paragraph [ref=e12]: Sign in to continue into your Scholesa workflow.
      - generic [ref=e13]:
        - generic [ref=e14]:
          - generic [ref=e15]:
            - text: Email address
            - textbox "Email address" [ref=e16]
          - generic [ref=e17]:
            - text: Password
            - textbox "Password" [ref=e18]
        - button "Sign in" [ref=e20]
        - link "Create an account" [ref=e22] [cursor=pointer]:
          - /url: /en/register
  - alert [ref=e23]
```