package com.doorworkflow.service;

import com.doorworkflow.entity.ProcessStep;
import com.doorworkflow.repository.JobRepository;
import com.doorworkflow.repository.JobStepRepository;
import com.doorworkflow.repository.ProcessStepRepository;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.ss.usermodel.Workbook;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.util.Collections;
import java.util.List;
import static org.assertj.core.api.Assertions.assertThat;

class LogExportZeroJobsIntegrationTest {

    @Test
    void exportWithZeroJobsCreatesSheetAndHeaders() throws IOException {
        JobRepository jobRepo = Mockito.mock(JobRepository.class);
        JobStepRepository stepRepo = Mockito.mock(JobStepRepository.class);
        ProcessStepRepository psRepo = Mockito.mock(ProcessStepRepository.class);

        Mockito.when(jobRepo.findAllByOrderByCreatedAtDesc()).thenReturn(Collections.emptyList());
        Mockito.when(stepRepo.findAll()).thenReturn(Collections.emptyList());
        Mockito.when(psRepo.findByIsActiveTrueOrderByStepOrderAsc()).thenReturn(List.of(
                buildProcessStep("Laser Cutting", 1),
                buildProcessStep("Bending", 2),
                buildProcessStep("Hardware Packaging", 3),
                buildProcessStep("Dispatch", 4)
        ));

        LogExportService service = new LogExportService(jobRepo, stepRepo, psRepo);
        byte[] bytes = service.generateJobLogsExcel();
        try (Workbook wb = new XSSFWorkbook(new ByteArrayInputStream(bytes))) {
            Sheet sheet = wb.getSheet("Job Logs");
            assertThat(sheet).isNotNull();
            assertThat(sheet.getRow(0)).isNotNull();
            // 11 fixed + 4 process steps + 2 final = 17
            assertThat(sheet.getRow(0).getPhysicalNumberOfCells()).isEqualTo(17);
            // No data rows
            assertThat(sheet.getLastRowNum()).isEqualTo(0);
        }
    }

    @Test
    void exportWithZeroProcessStepsProducesFixedColumnsOnly() throws IOException {
        JobRepository jobRepo = Mockito.mock(JobRepository.class);
        JobStepRepository stepRepo = Mockito.mock(JobStepRepository.class);
        ProcessStepRepository psRepo = Mockito.mock(ProcessStepRepository.class);

        Mockito.when(jobRepo.findAllByOrderByCreatedAtDesc()).thenReturn(Collections.emptyList());
        Mockito.when(stepRepo.findAll()).thenReturn(Collections.emptyList());
        Mockito.when(psRepo.findByIsActiveTrueOrderByStepOrderAsc()).thenReturn(Collections.emptyList());

        LogExportService service = new LogExportService(jobRepo, stepRepo, psRepo);
        byte[] bytes = service.generateJobLogsExcel();
        try (Workbook wb = new XSSFWorkbook(new ByteArrayInputStream(bytes))) {
            Sheet sheet = wb.getSheet("Job Logs");
            assertThat(sheet).isNotNull();
            assertThat(sheet.getRow(0)).isNotNull();
            // 11 fixed + 0 process steps + 2 final = 13
            assertThat(sheet.getRow(0).getPhysicalNumberOfCells()).isEqualTo(13);
        }
    }

    private ProcessStep buildProcessStep(String name, int order) {
        return ProcessStep.builder()
                .name(name)
                .stepOrder(order)
                .isActive(true)
                .build();
    }
}
