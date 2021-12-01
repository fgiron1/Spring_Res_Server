package com.fgiron.votosResourceServer.Auth;

import org.springframework.security.config.annotation.web.configuration.WebSecurityConfigurerAdapter;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.WebSecurityConfigurerAdapter;
import org.springframework.security.config.annotation.web.configurers.oauth2.server.resource.OAuth2ResourceServerConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.provisioning.InMemoryUserDetailsManager;
import org.springframework.stereotype.Component;

@Configuration
@Order(Ordered.LOWEST_PRECEDENCE)
public class WebSecurityConfig extends WebSecurityConfigurerAdapter {
	
	@Override
	protected void configure(HttpSecurity http) throws Exception {
		http
				.cors()
				.and()
				.csrf().disable()
				.sessionManagement().sessionCreationPolicy(SessionCreationPolicy.STATELESS)
				.and()
				.authorizeRequests(configurer ->
						configurer
								.antMatchers(
										"/error",
										"/login"
								)
								.permitAll()
								.anyRequest()
								.authenticated()
				)
				.oauth2ResourceServer(OAuth2ResourceServerConfigurer::jwt);
	}
	
	@Bean
	@Override
	protected UserDetailsService userDetailsService() {
		//Se instancia un tipo de usuario?
		UserDetails user1 = User
				.withUsername("user")
				.authorities("USER")
				.passwordEncoder(new BCryptPasswordEncoder()::encode)
				.password("1234")
				.build();
		
		InMemoryUserDetailsManager manager = new InMemoryUserDetailsManager();
		manager.createUser(user1);
		return manager;
	}

}
