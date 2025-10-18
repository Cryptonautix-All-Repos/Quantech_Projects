/* MetaTrader Trading Systems Portfolio - Smooth Scrolling */

(function() {
    'use strict';
    
    // Smooth scrolling for navigation links
    function initSmoothScrolling() {
        const navLinks = document.querySelectorAll('a[href^="#"]');
        const navbar = document.querySelector('.navbar');
        const navHeight = navbar ? navbar.offsetHeight : 80;
        
        navLinks.forEach(link => {
            link.addEventListener('click', function(e) {
                e.preventDefault();
                
                const targetId = this.getAttribute('href');
                const targetElement = document.querySelector(targetId);
                
                if (targetElement) {
                    const targetPosition = targetElement.offsetTop - navHeight - 20;
                    
                    // Smooth scroll to target
                    window.scrollTo({
                        top: targetPosition,
                        behavior: 'smooth'
                    });
                    
                    // Update active navigation link
                    updateActiveNavLink(targetId);
                    
                    // Close mobile menu if open
                    closeMobileMenu();
                }
            });
        });
    }
    
    // Update active navigation link
    function updateActiveNavLink(targetId) {
        const navLinks = document.querySelectorAll('.nav-links a');
        
        navLinks.forEach(link => {
            link.classList.remove('active');
            if (link.getAttribute('href') === targetId) {
                link.classList.add('active');
            }
        });
    }
    
    // Close mobile menu
    function closeMobileMenu() {
        const mobileMenu = document.getElementById('nav-links');
        const mobileToggle = document.getElementById('mobile-menu-toggle');
        
        if (mobileMenu && mobileToggle) {
            mobileMenu.classList.remove('active');
            mobileToggle.classList.remove('active');
        }
    }
    
    // Scroll spy functionality
    function initScrollSpy() {
        const sections = document.querySelectorAll('section[id]');
        const navLinks = document.querySelectorAll('.nav-links a[href^="#"]');
        const navbar = document.querySelector('.navbar');
        const navHeight = navbar ? navbar.offsetHeight : 80;
        
        function updateActiveLink() {
            const scrollPosition = window.scrollY + navHeight + 100;
            
            let currentSection = '';
            
            sections.forEach(section => {
                const sectionTop = section.offsetTop;
                const sectionHeight = section.offsetHeight;
                
                if (scrollPosition >= sectionTop && scrollPosition < sectionTop + sectionHeight) {
                    currentSection = '#' + section.id;
                }
            });
            
            // Update active navigation link
            navLinks.forEach(link => {
                link.classList.remove('active');
                if (link.getAttribute('href') === currentSection) {
                    link.classList.add('active');
                }
            });
        }
        
        // Throttled scroll event listener
        let ticking = false;
        
        function onScroll() {
            if (!ticking) {
                requestAnimationFrame(() => {
                    updateActiveLink();
                    ticking = false;
                });
                ticking = true;
            }
        }
        
        window.addEventListener('scroll', onScroll);
        
        // Initial call
        updateActiveLink();
    }
    
    // Navbar scroll effect
    function initNavbarScrollEffect() {
        const navbar = document.querySelector('.navbar');
        if (!navbar) return;
        
        let lastScrollTop = 0;
        let isScrolling = false;
        
        function handleScroll() {
            const scrollTop = window.pageYOffset || document.documentElement.scrollTop;
            
            // Add/remove scrolled class based on scroll position
            if (scrollTop > 100) {
                navbar.classList.add('scrolled');
            } else {
                navbar.classList.remove('scrolled');
            }
            
            // Hide/show navbar on scroll (optional)
            if (scrollTop > lastScrollTop && scrollTop > 200) {
                // Scrolling down
                navbar.style.transform = 'translateY(-100%)';
            } else {
                // Scrolling up
                navbar.style.transform = 'translateY(0)';
            }
            
            lastScrollTop = scrollTop <= 0 ? 0 : scrollTop;
            isScrolling = false;
        }
        
        window.addEventListener('scroll', () => {
            if (!isScrolling) {
                requestAnimationFrame(handleScroll);
                isScrolling = true;
            }
        });
    }
    
    // Scroll to top button
    function initScrollToTop() {
        // Create scroll to top button
        const scrollToTopBtn = document.createElement('button');
        scrollToTopBtn.innerHTML = '↑';
        scrollToTopBtn.className = 'scroll-to-top';
        scrollToTopBtn.setAttribute('aria-label', 'Scroll to top');
        scrollToTopBtn.style.cssText = `
            position: fixed;
            bottom: 2rem;
            right: 2rem;
            width: 50px;
            height: 50px;
            background: var(--gradient-gold);
            color: var(--primary-bg);
            border: none;
            border-radius: 50%;
            font-size: 1.2rem;
            font-weight: bold;
            cursor: pointer;
            opacity: 0;
            visibility: hidden;
            transition: all 0.3s ease;
            z-index: 999;
            box-shadow: 0 5px 15px rgba(255, 215, 0, 0.3);
        `;
        
        document.body.appendChild(scrollToTopBtn);
        
        // Show/hide button based on scroll position
        function toggleScrollToTopBtn() {
            if (window.scrollY > 300) {
                scrollToTopBtn.style.opacity = '1';
                scrollToTopBtn.style.visibility = 'visible';
            } else {
                scrollToTopBtn.style.opacity = '0';
                scrollToTopBtn.style.visibility = 'hidden';
            }
        }
        
        // Scroll to top functionality
        scrollToTopBtn.addEventListener('click', () => {
            window.scrollTo({
                top: 0,
                behavior: 'smooth'
            });
        });
        
        // Hover effects
        scrollToTopBtn.addEventListener('mouseenter', () => {
            scrollToTopBtn.style.transform = 'translateY(-3px)';
            scrollToTopBtn.style.boxShadow = '0 10px 25px rgba(255, 215, 0, 0.4)';
        });
        
        scrollToTopBtn.addEventListener('mouseleave', () => {
            scrollToTopBtn.style.transform = 'translateY(0)';
            scrollToTopBtn.style.boxShadow = '0 5px 15px rgba(255, 215, 0, 0.3)';
        });
        
        window.addEventListener('scroll', toggleScrollToTopBtn);
    }
    
    // Smooth reveal animations on scroll
    function initScrollReveal() {
        const observerOptions = {
            threshold: 0.1,
            rootMargin: '0px 0px -50px 0px'
        };
        
        const observer = new IntersectionObserver((entries) => {
            entries.forEach(entry => {
                if (entry.isIntersecting) {
                    entry.target.classList.add('animate-slide-up');
                    observer.unobserve(entry.target);
                }
            });
        }, observerOptions);
        
        // Observe elements for animation
        const animatedElements = document.querySelectorAll(
            '.strategy-card, .technical-card, .metric-card, .step-item, .info-card'
        );
        
        animatedElements.forEach(element => {
            observer.observe(element);
        });
    }
    
    // Parallax scrolling effect for hero background
    function initParallaxEffect() {
        const hero = document.querySelector('.hero');
        if (!hero) return;
        
        function updateParallax() {
            const scrolled = window.pageYOffset;
            const parallaxSpeed = 0.5;
            
            hero.style.transform = `translateY(${scrolled * parallaxSpeed}px)`;
        }
        
        // Throttled scroll event for performance
        let ticking = false;
        
        function onScroll() {
            if (!ticking) {
                requestAnimationFrame(() => {
                    updateParallax();
                    ticking = false;
                });
                ticking = true;
            }
        }
        
        window.addEventListener('scroll', onScroll);
    }
    
    // Enhanced smooth scrolling with easing
    function smoothScrollTo(target, duration = 800) {
        const targetElement = typeof target === 'string' ? document.querySelector(target) : target;
        if (!targetElement) return;
        
        const navbar = document.querySelector('.navbar');
        const navHeight = navbar ? navbar.offsetHeight : 80;
        const targetPosition = targetElement.offsetTop - navHeight - 20;
        const startPosition = window.pageYOffset;
        const distance = targetPosition - startPosition;
        let startTime = null;
        
        // Easing function
        function easeInOutCubic(t) {
            return t < 0.5 ? 4 * t * t * t : (t - 1) * (2 * t - 2) * (2 * t - 2) + 1;
        }
        
        function animation(currentTime) {
            if (startTime === null) startTime = currentTime;
            const timeElapsed = currentTime - startTime;
            const progress = Math.min(timeElapsed / duration, 1);
            const ease = easeInOutCubic(progress);
            
            window.scrollTo(0, startPosition + distance * ease);
            
            if (timeElapsed < duration) {
                requestAnimationFrame(animation);
            }
        }
        
        requestAnimationFrame(animation);
    }
    
    // Initialize when DOM is ready
    function init() {
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', () => {
                initSmoothScrolling();
                initScrollSpy();
                initNavbarScrollEffect();
                initScrollToTop();
                initScrollReveal();
                initParallaxEffect();
            });
        } else {
            initSmoothScrolling();
            initScrollSpy();
            initNavbarScrollEffect();
            initScrollToTop();
            initScrollReveal();
            initParallaxEffect();
        }
    }
    
    // Public API
    window.SmoothScroll = {
        scrollTo: smoothScrollTo,
        init: init
    };
    
    // Auto-initialize
    init();
    
})();