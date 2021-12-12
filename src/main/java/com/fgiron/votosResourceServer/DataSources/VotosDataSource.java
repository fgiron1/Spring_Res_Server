/*package com.fgiron.votosResourceServer.DataSources;

import javax.persistence.EntityManagerFactory;
import javax.sql.DataSource;

import com.fgiron.votosResourceServer.Repositories.Candidato_SenadoRepository;
import com.fgiron.votosResourceServer.Repositories.EleccionRepository;
import com.fgiron.votosResourceServer.Repositories.IntegranteRepository;
import com.fgiron.votosResourceServer.Repositories.Tipo_EleccionRepository;
import com.fgiron.votosResourceServer.Repositories.VotoRepository;
import com.fgiron.votosResourceServer.Repositories.Voto_PartidoRepository;
import com.fgiron.votosResourceServer.Repositories.Voto_SenadoRepository;
import com.fgiron.votosResourceServer.Repositories.VotoRepository;


import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.jdbc.DataSourceBuilder;
import org.springframework.boot.orm.jpa.EntityManagerFactoryBuilder;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;
import org.springframework.data.jpa.repository.config.EnableJpaRepositories;
import org.springframework.orm.jpa.JpaTransactionManager;
import org.springframework.orm.jpa.LocalContainerEntityManagerFactoryBean;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.EnableTransactionManagement;

@Configuration
@EnableTransactionManagement
@EnableJpaRepositories(
    entityManagerFactoryRef = "entityManagerFactory",
    basePackageClasses = {Candidato_SenadoRepository.class,
                          EleccionRepository.class,
                          IntegranteRepository.class,
                          Tipo_EleccionRepository.class,
                          Voto_PartidoRepository.class,
                          Voto_SenadoRepository.class,
                          VotoRepository.class}
)
public class VotosDataSource {
   
    @Primary
    @Bean(name = "datasource")
	@ConfigurationProperties( prefix = "spring.datasource")
	public DataSource dataSource(){
		return DataSourceBuilder.create().build();
	}

    @Primary
    @Bean(name = "entityManagerFactory")
    public LocalContainerEntityManagerFactoryBean entityManagerFactory(
        EntityManagerFactoryBuilder builder,
        @Qualifier("datasource") DataSource dataSource
    ) {
        return builder
        .dataSource(dataSource)
        .packages("com.fgiron.votosResourceServer.Models")
        .persistenceUnit("EntityManagerFactory")
        .build();
    }
    
    @Primary
    @Bean(name = "transactionManager")
    public PlatformTransactionManager transactionManager(
        @Qualifier("entityManagerFactory") EntityManagerFactory 
        entityManagerFactory
    ) {
        return new JpaTransactionManager(entityManagerFactory);
    }

}

*/
