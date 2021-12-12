/*package com.fgiron.votosResourceServer.DataSources;

import javax.persistence.EntityManagerFactory;
import javax.sql.DataSource;

import com.fgiron.votosResourceServer.Repositories_Identidades.Oauth_tokenRepository;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.autoconfigure.domain.EntityScan;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.jdbc.DataSourceBuilder;
import org.springframework.boot.orm.jpa.EntityManagerFactoryBuilder;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.jpa.repository.config.EnableJpaRepositories;
import org.springframework.orm.jpa.JpaTransactionManager;
import org.springframework.orm.jpa.LocalContainerEntityManagerFactoryBean;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.EnableTransactionManagement;

@Configuration
@EnableTransactionManagement
@EnableJpaRepositories(
    entityManagerFactoryRef = "entityManagerFactory-Identidades",
    basePackages = { "com.fgiron.votosResourceServer.Models_Identidades",
     "com.fgiron.votosResourceServer.Repositories_Identidades" }
)
@EntityScan()
public class IdentidadesDataSource {
    
    @Bean(name = "datasource-identidades")
	@ConfigurationProperties(prefix = "spring.datasource-identidades")
	public DataSource dataSource(){
		return DataSourceBuilder.create().build();
	}

    @Bean(name = "entityManagerFactory-Identidades")
    public LocalContainerEntityManagerFactoryBean entityManagerFactory(
        EntityManagerFactoryBuilder builder,
        @Qualifier("datasource-identidades") DataSource dataSource
    ) {
        return builder
        .dataSource(dataSource)
        .packages("com.fgiron.votosResourceServer.Models_Identidades")
        .persistenceUnit("EntityManagerFactory_Identidades")
        .build();
    }
    
    @Bean(name = "transactionManager-Identidades")
    public PlatformTransactionManager transactionManager(
        @Qualifier("entityManagerFactory-Identidades") EntityManagerFactory 
        entityManagerFactory
    ) {
        return new JpaTransactionManager(entityManagerFactory);
    }


}
*/