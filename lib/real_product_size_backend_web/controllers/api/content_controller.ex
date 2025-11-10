defmodule RealProductSizeBackendWeb.Api.ContentController do
  use RealProductSizeBackendWeb, :controller

  def privacy(conn, _params) do
    content = """
    <div class="prose prose-lg max-w-none">
      <h1>Privacy Policy</h1>
      <p>Last updated: January 27, 2025</p>

      <h2>Introduction</h2>
      <p>Real Product View ("we," "our," or "us") respects your privacy and is committed to protecting your personal information. This Privacy Policy explains how we collect, use, and safeguard your information when you use our mobile application.</p>

      <h2>Information We Collect</h2>

      <h3>Camera and AR Data</h3>
      <p>Our app uses your device's camera to provide augmented reality functionality. Camera data is processed locally on your device and is not transmitted to our servers. We do not store, collect, or share your camera feed or AR session data.</p>

      <h3>App Usage Data</h3>
      <p>We may collect anonymous usage statistics to improve our app, including:</p>
      <ul>
        <li>App performance metrics</li>
        <li>Feature usage frequency</li>
        <li>Crash reports and error logs</li>
        <li>Device type and OS version</li>
      </ul>

      <h3>Account Information</h3>
      <p>If you choose to create an account, we collect:</p>
      <ul>
        <li>Email address</li>
        <li>Username (if provided)</li>
        <li>Account preferences</li>
      </ul>

      <h2>How We Use Your Information</h2>
      <p>We use the information we collect to:</p>
      <ul>
        <li>Provide and improve our AR product visualization services</li>
        <li>Process your account and preferences</li>
        <li>Send you important app updates and notifications</li>
        <li>Analyze app performance and fix bugs</li>
        <li>Respond to your support requests</li>
      </ul>

      <h2>Data Storage and Security</h2>
      <p>We implement appropriate security measures to protect your personal information. Your data is stored securely and is only accessible to authorized personnel who need it to provide our services.</p>

      <h2>Third-Party Services</h2>
      <p>Our app may integrate with third-party services for analytics and crash reporting. These services have their own privacy policies, and we encourage you to review them.</p>

      <h2>Your Rights</h2>
      <p>You have the right to:</p>
      <ul>
        <li>Access your personal information</li>
        <li>Correct inaccurate information</li>
        <li>Delete your account and associated data</li>
        <li>Opt out of non-essential communications</li>
      </ul>

      <h2>Children's Privacy</h2>
      <p>Our app is not intended for children under 13. We do not knowingly collect personal information from children under 13. If you believe we have collected information from a child under 13, please contact us immediately.</p>

      <h2>Contact Us</h2>
      <p>If you have any questions about this Privacy Policy, please contact us at:</p>
      <p>Email: privacy@realproductview.com</p>
      <p>Support Page: /support</p>

      <h2>Changes to This Policy</h2>
      <p>We may update this Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page and updating the "Last updated" date.</p>
    </div>
    """

    json(conn, %{
      title: "Privacy Policy",
      last_updated: "January 27, 2025",
      content: content
    })
  end

  def terms(conn, _params) do
    content = """
    <div class="prose prose-lg max-w-none">
      <h1>Terms of Service</h1>
      <p>Last updated: January 27, 2025</p>

      <h2>Agreement to Terms</h2>
      <p>By downloading, installing, or using the Real Product View mobile application ("App"), you agree to be bound by these Terms of Service ("Terms"). If you do not agree to these Terms, please do not use our App.</p>

      <h2>Description of Service</h2>
      <p>Real Product View is a mobile application that uses augmented reality technology to help users visualize products in their physical space. The App allows users to:</p>
      <ul>
        <li>Place 3D product models in real-world environments using their device's camera</li>
        <li>View products at accurate scale and proportions</li>
        <li>Make informed purchasing decisions based on visual representation</li>
      </ul>

      <h2>User Responsibilities</h2>
      <p>As a user of our App, you agree to:</p>
      <ul>
        <li>Use the App only for lawful purposes</li>
        <li>Not attempt to reverse engineer, modify, or distribute the App</li>
        <li>Respect the intellectual property rights of others</li>
        <li>Use the App in a safe manner, especially when using AR features</li>
        <li>Not use the App while driving or in situations where it may be dangerous</li>
      </ul>

      <h2>Camera and AR Usage</h2>
      <p>Our App requires access to your device's camera to provide AR functionality. By granting camera permission, you acknowledge that:</p>
      <ul>
        <li>Camera data is processed locally on your device</li>
        <li>We do not store or transmit your camera feed</li>
        <li>You are responsible for using the camera feature safely and legally</li>
        <li>You should not use the App in private areas without permission</li>
      </ul>

      <h2>Intellectual Property</h2>
      <p>The App and its original content, features, and functionality are owned by Real Product View and are protected by international copyright, trademark, and other intellectual property laws.</p>

      <h2>Privacy</h2>
      <p>Your privacy is important to us. Please review our <a href="/privacy">Privacy Policy</a> to understand how we collect, use, and protect your information.</p>

      <h2>Disclaimers</h2>
      <p>The App is provided "as is" without warranties of any kind. We do not guarantee that:</p>
      <ul>
        <li>The App will be error-free or uninterrupted</li>
        <li>AR measurements will be perfectly accurate</li>
        <li>Product models will exactly match real products</li>
        <li>The App will be compatible with all devices</li>
      </ul>

      <h2>Limitation of Liability</h2>
      <p>In no event shall Real Product View be liable for any indirect, incidental, special, consequential, or punitive damages, including without limitation, loss of profits, data, use, goodwill, or other intangible losses, resulting from your use of the App.</p>

      <h2>App Store Terms</h2>
      <p>If you downloaded the App from the Apple App Store or Google Play Store, you also agree to the terms and conditions of those platforms. In case of conflict between these Terms and the platform terms, the platform terms shall prevail.</p>

      <h2>Updates and Changes</h2>
      <p>We may update the App and these Terms from time to time. Continued use of the App after changes constitutes acceptance of the new Terms.</p>

      <h2>Termination</h2>
      <p>We may terminate or suspend your access to the App immediately, without prior notice, for any reason, including if you breach these Terms.</p>

      <h2>Governing Law</h2>
      <p>These Terms shall be governed by and construed in accordance with the laws of the jurisdiction in which Real Product View operates, without regard to conflict of law principles.</p>

      <h2>Contact Information</h2>
      <p>If you have any questions about these Terms, please contact us at:</p>
      <p>Email: legal@realproductview.com</p>
      <p>Support Page: /support</p>
    </div>
    """

    json(conn, %{
      title: "Terms of Service",
      last_updated: "January 27, 2025",
      content: content
    })
  end
end
