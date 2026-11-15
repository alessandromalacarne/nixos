Feature: Host notification broker for jailed agent hooks
  Command Code runs inside ai-jail, which denies the session D-Bus bus, the
  PipeWire/Pulse socket and the display. Its Stop hook therefore cannot reach
  the desktop notification daemon (noctalia) or play a sound. A small broker
  runs as a systemd user service on the host, owns a Unix socket inside the
  jail's shared `~/.commandcode` map, and performs the real notification and
  playback on behalf of the jailed hook. The hook keeps a direct fallback so
  it still behaves correctly when it runs outside the sandbox.

  Design decisions (agreed):
    - transport: HTTP over Unix socket `~/.commandcode/notify.sock`
    - scope: desktop notification (notify-send) + optional sound (paplay)
    - the broker is a Home Manager `systemd.user.services` unit, so it
      inherits the niri session bus and does not need mako
    - the hook path stays `~/.commandcode/hooks/session-end-notify.sh`

  Background:
    Given the desktop user has an active graphical session
    And the noctalia notification daemon is running on the session bus
    And the notify-broker user service is active
    And the notify-broker listens on the Unix socket "~/.commandcode/notify.sock"
    And the Command Code Stop hook is installed at "~/.commandcode/hooks/session-end-notify.sh"

  @functional
  Scenario: A finished turn produces a desktop notification
    When the Stop hook posts a request with title "Command Code" and body "Session finished"
    Then the broker responds with status 204
    And notify-send is invoked exactly once with title "Command Code" and body "Session finished"
    And the noctalia daemon receives one notification

  @functional
  Scenario: Urgency is forwarded to notify-send
    When the Stop hook posts a request with urgency "critical"
    Then notify-send is invoked with urgency "critical"

  @functional
  Scenario: Sound is played when requested
    Given the request sets sound to true
    When the broker accepts the request
    Then the broker starts paplay with the "message-new-instant" sound without waiting for it to finish
    And the broker responds with status 204

  @functional
  Scenario: Sound is skipped when not requested
    Given the request sets sound to false
    When the broker accepts the request
    Then the broker does not start paplay
    And the broker responds with status 204

  @functional
  Scenario: The hook prefers the broker over direct tools
    Given the broker socket accepts connections
    When the Stop hook fires after a finished turn
    Then the hook posts a notification request to the broker socket
    And the hook does not invoke notify-send or paplay directly
    And the hook exits with status 0

  @functional @reliability
  Scenario: The hook falls back when the broker is unavailable
    Given the broker socket is absent or refuses connections
    When the Stop hook fires after a finished turn
    Then the hook invokes notify-send directly
    And the hook invokes paplay directly when a sound file is available
    And the hook exits with status 0 regardless of whether those tools succeed

  @functional @reliability
  Scenario: The hook falls back when the broker errors
    Given the broker responds with status 500
    When the Stop hook fires after a finished turn
    Then the hook invokes notify-send directly
    And the hook exits with status 0

  @functional @edge-case
  Scenario Outline: Invalid requests are rejected without notifying
    When a client posts <payload>
    Then the broker responds with status <status>
    And no notification is requested
    And the broker keeps serving subsequent requests

    Examples:
      | payload                          | status |
      | an empty body                    | 400    |
      | a body that is not valid JSON    | 400    |
      | a JSON body without a title      | 400    |
      | a JSON body without a body       | 400    |
      | a request with method GET        | 405    |
      | a body larger than 64 KiB        | 413    |

  @functional @edge-case
  Scenario: Concurrent turn completions are all notified
    When 5 Stop hooks post simultaneously
    Then all 5 requests respond with status 204
    And notify-send is invoked 5 times

  @functional @edge-case
  Scenario: Unicode and multiline text are preserved
    When the Stop hook posts a title with emoji and a body with line breaks
    Then the notification content matches the request byte for byte

  @functional @edge-case
  Scenario: A second hook run does not duplicate the notification
    Given the broker accepted the first request
    When the hook is re-run with the same payload
    Then notify-send is invoked once per request and not twice for one request
    And no fallback path runs

  @non-functional @performance
  Scenario: The broker answers within budget
    When the broker receives 100 sequential valid requests
    Then the 95th percentile response time is at most 100 ms
    And no response takes longer than 500 ms

  @non-functional @performance
  Scenario: The hook never blocks the agent turn
    Given the broker socket is absent
    When the Stop hook fires
    Then the hook process finishes within 2 seconds
    And the hook exits with status 0

  @non-functional @security
  Scenario: The socket is private to the desktop user
    Then the socket file has mode 0600
    And the socket file is owned by the desktop user
    And the broker listens on no TCP address

  @non-functional @security
  Scenario: Request content is never interpreted by a shell
    When a client posts a title containing shell metacharacters
    Then no shell command derived from the payload is executed
    And notify-send receives the literal text as a single argument

  @non-functional @security
  Scenario: The broker only performs the allowlisted actions
    Then the broker can invoke only notify-send and paplay
    And it never executes a client-supplied path or command

  @non-functional @reliability
  Scenario: A stale socket does not prevent startup
    Given a socket file exists at "~/.commandcode/notify.sock" with no listener
    When the notify-broker service starts
    Then it replaces the stale socket and accepts connections

  @non-functional @reliability
  Scenario: Playback failure does not fail the notification
    Given paplay is missing or fails
    When the broker accepts a request with sound enabled
    Then the broker still responds with status 204
    And notify-send is still invoked

  @non-functional @reliability
  Scenario: The service recovers from a crash
    Given the notify-broker process is killed
    Then systemd restarts the service
    And the socket accepts connections again

  @non-functional @reliability
  Scenario: A session without a bus degrades cleanly
    Given the user session has no D-Bus session bus
    When the broker posts a notification
    Then the broker responds with status 503
    And the hook still exits with status 0

  @non-functional @observability
  Scenario: Every request leaves a trace in the journal
    When the broker handles a request
    Then the journal records the request outcome and duration
    And the log contains no notification body content beyond what the user already sees

  @non-functional @configurability
  Scenario: The socket path can be overridden
    Given the environment variable NOTIFY_BROKER_SOCKET points to another path
    When the hook fires
    Then the hook posts to that path instead of the default
