/* MetaTrader Trading Systems Portfolio - Interactive Elements */

(function() {
    'use strict';
    
    // Strategy detail tabs functionality
    function initStrategyTabs() {
        const tabButtons = document.querySelectorAll('.tab-btn');
        const tabContents = document.querySelectorAll('.tab-content');
        
        tabButtons.forEach(button => {
            button.addEventListener('click', () => {
                const targetTab = button.getAttribute('data-tab');
                
                // Remove active class from all tabs
                tabButtons.forEach(btn => btn.classList.remove('active'));
                tabContents.forEach(content => content.classList.remove('active'));
                
                // Add active class to clicked tab and corresponding content
                button.classList.add('active');
                const targetContent = document.getElementById(targetTab);
                if (targetContent) {
                    targetContent.classList.add('active');
                }
            });
        });
        
        // Learn more buttons
        const learnMoreButtons = document.querySelectorAll('.learn-more-btn');
        learnMoreButtons.forEach(button => {
            button.addEventListener('click', (e) => {
                e.preventDefault();
                const target = button.getAttribute('data-target');
                if (target) {
                    // Switch to the corresponding tab
                    const tabButton = document.querySelector(`[data-tab="${target}"]`);
                    if (tabButton) {
                        // Remove active from all tabs first
                        document.querySelectorAll('.tab-btn').forEach(btn => btn.classList.remove('active'));
                        document.querySelectorAll('.tab-content').forEach(content => content.classList.remove('active'));
                        
                        // Activate the correct tab
                        tabButton.classList.add('active');
                        const targetContent = document.getElementById(target);
                        if (targetContent) {
                            targetContent.classList.add('active');
                        }
                    }
                    
                    // Scroll to strategy details section
                    const detailsSection = document.getElementById('strategy-details');
                    if (detailsSection) {
                        detailsSection.scrollIntoView({ 
                            behavior: 'smooth',
                            block: 'start'
                        });
                    }
                }
            });
        });
    }
    
    // Mobile menu toggle
    function initMobileMenu() {
        const mobileToggle = document.getElementById('mobile-menu-toggle');
        const navLinks = document.getElementById('nav-links');
        
        if (mobileToggle && navLinks) {
            mobileToggle.addEventListener('click', () => {
                mobileToggle.classList.toggle('active');
                navLinks.classList.toggle('active');
                
                // Prevent body scroll when menu is open
                if (navLinks.classList.contains('active')) {
                    document.body.style.overflow = 'hidden';
                } else {
                    document.body.style.overflow = '';
                }
            });
            
            // Close menu when clicking on a link
            const navLinkItems = navLinks.querySelectorAll('a');
            navLinkItems.forEach(link => {
                link.addEventListener('click', () => {
                    mobileToggle.classList.remove('active');
                    navLinks.classList.remove('active');
                    document.body.style.overflow = '';
                });
            });
            
            // Close menu when clicking outside
            document.addEventListener('click', (e) => {
                if (!mobileToggle.contains(e.target) && !navLinks.contains(e.target)) {
                    mobileToggle.classList.remove('active');
                    navLinks.classList.remove('active');
                    document.body.style.overflow = '';
                }
            });
        }
    }
    
    // Initialize the application
    function init() {
        // Wait for DOM to be ready
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', () => {
                initStrategyTabs();
                initMobileMenu();
            });
        } else {
            initStrategyTabs();
            initMobileMenu();
        }
    }
    
    // Start the application
    init();
    
})();