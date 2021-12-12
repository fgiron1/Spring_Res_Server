package com.fgiron.votosResourceServer.Auth;

import javax.sql.DataSource;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.security.config.annotation.authentication.builders.AuthenticationManagerBuilder;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configuration.WebSecurityConfigurerAdapter;
import org.springframework.security.config.annotation.web.configurers.oauth2.server.resource.OAuth2ResourceServerConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.provisioning.InMemoryUserDetailsManager;

@Configuration
@Order(Ordered.HIGHEST_PRECEDENCE)
@EnableWebSecurity
public class WebSecurityConfig extends WebSecurityConfigurerAdapter {
	
	@Autowired
	private JwtDecoder decoder;

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
										"/integrantes",
										"/integrantes/**",
										"eleccion",
										"eleccion/**",
										"voto",
										"voto_senado",
										"tipo_eleccion",
										"tipo_eleccion/**",
										"partidos",
										"partidos/**",
										"authorized"
								)
								.permitAll()
								.anyRequest()
								.authenticated()
				)
				.oauth2ResourceServer((oauth2) -> oauth2
					.jwt((jwt) -> jwt.decoder(this.decoder)));
	}
	
	@Bean
	@Override
	protected UserDetailsService userDetailsService() {
		//Se instancia un tipo de usuario?
		/*UserDetails user1 = User
				.withUsername("user")
				.authorities("USER")
				.passwordEncoder(new BCryptPasswordEncoder()::encode)
				.password("1234")
				.build();
		manager.createUser(user1);*/

		InMemoryUserDetailsManager manager = new InMemoryUserDetailsManager();
		return manager;
	}

}
