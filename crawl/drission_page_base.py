import random

from DrissionPage import WebPage, ChromiumOptions
from DrissionPage._elements.chromium_element import ChromiumElement
from DrissionPage._pages.chromium_tab import ChromiumTab
from random_user_agent.params import SoftwareName, OperatingSystem
from random_user_agent.user_agent import UserAgent


class DrissionPageBase(object):
    def __init__(
        self,
        window_size: str = "full",
        is_headless: bool = False,
        is_incognito: bool = False,
        is_user_agent: bool = False,
        time_implicitly_wait: int = 10,
        driver_name: str = "chrome",
        debug_port: int = 9222,
    ):
        co = ChromiumOptions()

        if is_headless:
            co.set_argument('--headless')
            co.set_argument('--no-sandbox')

        if is_incognito:
            co.set_argument('--incognito')

        if is_user_agent:
            user_agent = self._config_user_agent()
            co.set_user_agent(user_agent)

        co.set_argument('--disable-dev-shm-usage')
        co.set_argument('--disable-gpu')

        if window_size == 'full':
            co.set_argument('--start-maximized')
        else:
            co.set_argument('--window-size', value=window_size)

        if debug_port != -1:
            co.set_address(f'127.0.0.1:{debug_port}')

        if driver_name == 'chrome':
            co.set_browser_path('usr/bin/google-chrome')
        elif driver_name == 'brave':
            co.set_browser_path('usr/bin/brave-browser')
        elif driver_name == 'opera':
            co.set_browser_path('usr/bin/opera')
        elif driver_name == 'edge':
            co.set_browser_path('usr/bin/microsoft-edge-dev')
        else:
            raise Exception(f"Unsupported driver name: {driver_name}")

        self.page = WebPage(chromium_options=co, timeout=time_implicitly_wait)

    @staticmethod
    def _config_user_agent():
        software_names = [SoftwareName.CHROME.value]
        operating_systems = [OperatingSystem.WINDOWS.value, OperatingSystem.LINUX.value, OperatingSystem.MAC.value]
        user_agent_rotator = UserAgent(software_names=software_names,
                                       operating_systems=operating_systems, limit=100)
        user_agent = user_agent_rotator.get_random_user_agent()
        return user_agent

    def open_url(self, url, retry: int = 3, interval: int = 3, timeout: int = 30):
        self.page.get(url, retry=retry, interval=interval, timeout=timeout)

    def quit(self):
        self.page.quit()

    def set_window_size(self, width, height):
        self.page.set.window.size(width=width, height=height)

    def set_window_position(self, x, y):
        self.page.set.window.location(x=x, y=y)

    def sleep_for_seconds(self, seconds: float = 30):
        self.page.wait(seconds)

    def open_new_tab(self, url, quiet: bool = False):
        tab = self.page.new_tab(url, background=quiet)
        self.page.wait.new_tab()
        return tab

    def slow_scroll(self):
        self.page.set.scroll.smooth(True)
        self.page.set.scroll.wait_complete(True)
        delay_amount = random.uniform(0.5, 2)
        scroll_amount = random.randint(500, 1000)
        for _ in range(5):
            self.page.scroll.down(scroll_amount)
            self.page.wait(delay_amount)

    def go_back(self):
        self.page.back()

    def reload(self):
        self.page.refresh()

    def set_mode(self, mode: str, go: bool = True):
        self.page.change_mode(mode, go=go)

    def enable_mobile_mode(self):
        mobile_emulation = {
            "width": 411,  # Viewport width
            "height": 731,  # Viewport height
            "deviceScaleFactor": 2.625,  # Pixel ratio
            "mobile": True,  # Enable mobile events (touch, etc.)
            "screenOrientation": {"angle": 0, "type": "portraitPrimary"}  # Optional: Orientation
        }
        self.page.run_cdp("Emulation.setDeviceMetricsOverride", **mobile_emulation)

        # Set mobile user agent
        ua = {
            "userAgent": "Mozilla/5.0 (Linux; Android 8.0.0; Pixel Build/OPR3.170623.007) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/67.0.3396.68 Mobile Safari/537.36",
            "platform": "Android"  # Optional
        }
        self.page.run_cdp("Emulation.setUserAgentOverride", **ua)
        
    def touch_tap(self, tab: ChromiumTab, element: ChromiumElement) -> None:
        # Ensure element is in view (optional but recommended for mobile scrolling)
        element.scroll.to_see()

        # Get element's viewport rectangle
        bounding_rect = element.run_js('return this.getBoundingClientRect();')

        # Calculate center coordinates
        center_x = bounding_rect['x'] + (bounding_rect['width'] / 2)
        center_y = bounding_rect['y'] + (bounding_rect['height'] / 2)

        # Define touch point for a basic tap
        touch_point = {
            'x': center_x,
            'y': center_y,
            'id': 0,  # Unique touch identifier
            'radiusX': 1,  # Simulated finger radius
            'radiusY': 1,
            'force': 1  # Touch pressure (0-1)
        }

        # Simulate finger down (touchStart)
        tab.run_cdp('Input.dispatchTouchEvent', type='touchStart', touchPoints=[touch_point])

        self.sleep_for_seconds(0.1)

        # Simulate finger up (touchEnd) - instant tap, add time.sleep(0.1) if a press is needed
        tab.run_cdp('Input.dispatchTouchEvent', type='touchEnd', touchPoints=[touch_point])
